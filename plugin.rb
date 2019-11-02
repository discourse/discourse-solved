# frozen_string_literal: true

# name: discourse-solved
# about: Add a solved button to answers on Discourse
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-solved

enabled_site_setting :solved_enabled

if respond_to?(:register_svg_icon)
  register_svg_icon "far fa-check-square"
  register_svg_icon "check-square"
  register_svg_icon "far fa-square"
end

PLUGIN_NAME = "discourse_solved".freeze

register_asset 'stylesheets/solutions.scss'
register_asset 'stylesheets/mobile/solutions.scss', :mobile

after_initialize do

  [
    '../app/serializers/concerns/topic_answer_mixin.rb'
  ].each { |path| load File.expand_path(path, __FILE__) }

  skip_db = defined?(GlobalSetting.skip_db?) && GlobalSetting.skip_db?

  # we got to do a one time upgrade
  if !skip_db && defined?(UserAction::SOLVED)
    unless $redis.get('solved_already_upgraded')
      unless UserAction.where(action_type: UserAction::SOLVED).exists?
        Rails.logger.info("Upgrading storage for solved")
        sql = <<SQL
        INSERT INTO user_actions(action_type,
                                 user_id,
                                 target_topic_id,
                                 target_post_id,
                                 acting_user_id,
                                 created_at,
                                 updated_at)
        SELECT :solved,
               p.user_id,
               p.topic_id,
               p.id,
               t.user_id,
               pc.created_at,
               pc.updated_at
        FROM
          post_custom_fields pc
        JOIN
          posts p ON p.id = pc.post_id
        JOIN
          topics t ON t.id = p.topic_id
        WHERE
          pc.name = 'is_accepted_answer' AND
          pc.value = 'true' AND
          p.user_id IS NOT NULL
SQL

        DB.exec(sql, solved: UserAction::SOLVED)
      end
      $redis.set("solved_already_upgraded", "true")
    end
  end

  module ::DiscourseSolved
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSolved
    end

    AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD = "solved_auto_close_topic_timer_id".freeze

    def self.accept_answer!(post, acting_user, topic: nil)
      topic ||= post.topic
      accepted_id = topic.custom_fields["accepted_answer_post_id"].to_i

      if accepted_id > 0
        if p2 = Post.find_by(id: accepted_id)
          p2.custom_fields["is_accepted_answer"] = nil
          p2.save!

          if defined?(UserAction::SOLVED)
            UserAction.where(
              action_type: UserAction::SOLVED,
              target_post_id: p2.id
            ).destroy_all
          end
        end
      end

      post.custom_fields["is_accepted_answer"] = "true"
      topic.custom_fields["accepted_answer_post_id"] = post.id

      if defined?(UserAction::SOLVED)
        UserAction.log_action!(
          action_type: UserAction::SOLVED,
          user_id: post.user_id,
          acting_user_id: acting_user.id,
          target_post_id: post.id,
          target_topic_id: post.topic_id
        )
      end

      unless acting_user.id == post.user_id
        Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: post.user_id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          data: {
            message: 'solved.accepted_notification',
            display_username: acting_user.username,
            topic_title: topic.title
          }.to_json
        )
      end

      auto_close_hours = SiteSetting.solved_topics_auto_close_hours

      if (auto_close_hours > 0) && !topic.closed
        topic_timer = topic.set_or_create_timer(
          TopicTimer.types[:close],
          auto_close_hours,
          based_on_last_post: true
        )

        topic.custom_fields[
          AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD
        ] = topic_timer.id

        MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
      end

      topic.save!
      post.save!

      DiscourseEvent.trigger(:accepted_solution, post)
    end

    def self.unaccept_answer!(post, topic: nil)
      topic ||= post.topic
      post.custom_fields["is_accepted_answer"] = nil
      topic.custom_fields["accepted_answer_post_id"] = nil

      if timer_id = topic.custom_fields[AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD]
        topic_timer = TopicTimer.find_by(id: timer_id)
        topic_timer.destroy! if topic_timer
        topic.custom_fields[AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD] = nil
      end

      topic.save!
      post.save!

      # TODO remove_action! does not allow for this type of interface
      if defined? UserAction::SOLVED
        UserAction.where(
          action_type: UserAction::SOLVED,
          target_post_id: post.id
        ).destroy_all
      end

      # yank notification
      notification = Notification.find_by(
        notification_type: Notification.types[:custom],
        user_id: post.user_id,
        topic_id: post.topic_id,
        post_number: post.post_number
      )

      notification.destroy! if notification
      DiscourseEvent.trigger(:unaccepted_solution, post)
    end
  end

  require_dependency "application_controller"
  class DiscourseSolved::AnswerController < ::ApplicationController

    def accept

      limit_accepts

      post = Post.find(params[:id].to_i)

      topic = post.topic
      topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

      guardian.ensure_can_accept_answer!(topic)

      DiscourseSolved.accept_answer!(post, current_user, topic: topic)

      render json: success_json
    end

    def unaccept

      limit_accepts

      post = Post.find(params[:id].to_i)

      topic = post.topic
      topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

      guardian.ensure_can_accept_answer!(topic)

      DiscourseSolved.unaccept_answer!(post, topic: topic)
      render json: success_json
    end

    def limit_accepts
      unless current_user.staff?
        RateLimiter.new(nil, "accept-hr-#{current_user.id}", 20, 1.hour).performed!
        RateLimiter.new(nil, "accept-min-#{current_user.id}", 4, 30.seconds).performed!
      end
    end
  end

  DiscourseSolved::Engine.routes.draw do
    post "/accept" => "answer#accept"
    post "/unaccept" => "answer#unaccept"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseSolved::Engine, at: "solution"
  end

  TopicView.add_post_custom_fields_whitelister do |user|
    ["is_accepted_answer"]
  end

  def before_head_close_meta(controller)
    return "" if !controller.instance_of? TopicsController

    topic_view = controller.instance_variable_get(:@topic_view)
    topic = topic_view&.topic
    return "" if !topic
    # note, we have canonicals so we only do this for page 1 at the moment
    # it can get confusing to have this on every page and it should make page 1
    # a bit more prominent + cut down on pointless work

    return "" if !controller.guardian.allow_accepted_answers_on_category?(topic.category_id)

    first_post = topic_view.posts&.first
    return "" if first_post&.post_number != 1

    question_json = {
      '@type' => 'Question',
      'name' => topic.title,
      'text' => first_post.excerpt(nil, keep_onebox_body: true),
      'upvoteCount' => first_post.like_count,
      'answerCount' => 0,
      'dateCreated' => topic.created_at,
      'author' => {
        '@type' => 'Person',
        'name' => topic.user&.name
      }
    }

    if accepted_answer = Post.find_by(id: topic.custom_fields["accepted_answer_post_id"])
      question_json['answerCount'] = 1
      question_json[:acceptedAnswer] = {
        '@type' => 'Answer',
        'text' => accepted_answer.excerpt(nil, keep_onebox_body: true),
        'upvoteCount' => accepted_answer.like_count,
        'dateCreated' => accepted_answer.created_at,
        'url' => accepted_answer.full_url,
        'author' => {
          '@type' => 'Person',
          'name' => accepted_answer.user&.username
        }
      }
    end

    ['<script type="application/ld+json">', MultiJson.dump(
      '@context' => 'http://schema.org',
      '@type' => 'QAPage',
      'name' => topic&.title,
      'mainEntity' => question_json
    ).gsub("</", "<\\/").html_safe, '</script>'].join("")
  end

  register_html_builder('server:before-head-close-crawler') do |controller|
    before_head_close_meta(controller)
  end

  register_html_builder('server:before-head-close') do |controller|
    before_head_close_meta(controller)
  end

  if Report.respond_to?(:add_report)
    Report.add_report("accepted_solutions") do |report|
      report.data = []

      accepted_solutions = TopicCustomField.where(name: "accepted_answer_post_id")

      if report.respond_to?(:add_filter)
        category_filter = report.filters.dig(:category)
        report.add_filter('category', default: category_filter)
        if category_filter
          accepted_solutions = accepted_solutions.joins(:topic).where("topics.category_id = ?", category_filter)
        end
      else
        if report.category_id
          accepted_solutions = accepted_solutions.joins(:topic).where("topics.category_id = ?", report.category_id)
        end
      end

      accepted_solutions.where("topic_custom_fields.created_at >= ?", report.start_date)
        .where("topic_custom_fields.created_at <= ?", report.end_date)
        .group("DATE(topic_custom_fields.created_at)")
        .order("DATE(topic_custom_fields.created_at)")
        .count
        .each do |date, count|
        report.data << { x: date, y: count }
      end
      report.total = accepted_solutions.count
      report.prev30Days = accepted_solutions.where("topic_custom_fields.created_at >= ?", report.start_date - 30.days)
        .where("topic_custom_fields.created_at <= ?", report.start_date)
        .count
    end
  end

  if defined?(UserAction::SOLVED)
    require_dependency 'user_summary'
    class ::UserSummary
      def solved_count
        UserAction
          .where(user: @user)
          .where(action_type: UserAction::SOLVED)
          .count
      end
    end

    require_dependency 'user_summary_serializer'
    class ::UserSummarySerializer
      attributes :solved_count

      def solved_count
        object.solved_count
      end
    end
  end

  require_dependency 'topic_view_serializer'
  class ::TopicViewSerializer
    attributes :accepted_answer

    def include_accepted_answer?
      accepted_answer_post_id
    end

    def accepted_answer
      if info = accepted_answer_post_info
        {
          post_number: info[0],
          username: info[1],
          excerpt: info[2]
        }
      end
    end

    def accepted_answer_post_info
      # TODO: we may already have it in the stream ... so bypass query here
      postInfo = Post.where(id: accepted_answer_post_id, topic_id: object.topic.id)
        .joins(:user)
        .pluck('post_number', 'username', 'cooked')
        .first

      if postInfo
        postInfo[2] = if SiteSetting.solved_quote_length > 0
          PrettyText.excerpt(postInfo[2], SiteSetting.solved_quote_length, keep_emoji_images: true)
        else
          nil
        end
        return postInfo
      end
    end

    def accepted_answer_post_id
      id = object.topic.custom_fields["accepted_answer_post_id"]
      # a bit messy but race conditions can give us an array here, avoid
      id && id.to_i rescue nil
    end

  end

  class ::Category
    after_save :reset_accepted_cache

    protected
    def reset_accepted_cache
      ::Guardian.reset_accepted_answer_cache
    end
  end

  class ::Guardian

    @@allowed_accepted_cache = DistributedCache.new("allowed_accepted")

    def self.reset_accepted_answer_cache
      @@allowed_accepted_cache["allowed"] =
        begin
          Set.new(
            CategoryCustomField
              .where(name: "enable_accepted_answers", value: "true")
              .pluck(:category_id)
          )
        end
    end

    def allow_accepted_answers_on_category?(category_id)
      return true if SiteSetting.allow_solved_on_all_topics

      self.class.reset_accepted_answer_cache unless @@allowed_accepted_cache["allowed"]
      @@allowed_accepted_cache["allowed"].include?(category_id)
    end

    def can_accept_answer?(topic)
      topic && allow_accepted_answers_on_category?(topic.category_id) && (
        is_staff? || (
          authenticated? && ((!topic.closed? && topic.user_id == current_user.id) ||
                            (current_user.trust_level >= SiteSetting.accept_all_solutions_trust_level))
        )
      )
    end
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :can_accept_answer, :can_unaccept_answer, :accepted_answer

    def can_accept_answer
      topic = (topic_view && topic_view.topic) || object.topic

      if topic
        return scope.can_accept_answer?(topic) && object.post_number > 1 && !accepted_answer
      end

      false
    end

    def can_unaccept_answer
      topic = (topic_view && topic_view.topic) || object.topic
      if topic
        return scope.can_accept_answer?(topic) && (post_custom_fields["is_accepted_answer"] == 'true')
      end
    end

    def accepted_answer
      post_custom_fields["is_accepted_answer"] == 'true'
    end
  end

  require_dependency 'search'

  #TODO Remove when plugin is 1.0
  if Search.respond_to? :advanced_filter
    Search.advanced_filter(/in:solved/) do |posts|
      posts.where("topics.id IN (
        SELECT tc.topic_id
        FROM topic_custom_fields tc
        WHERE tc.name = 'accepted_answer_post_id' AND
                        tc.value IS NOT NULL
        )")

    end

    Search.advanced_filter(/in:unsolved/) do |posts|
      posts.where("topics.id NOT IN (
        SELECT tc.topic_id
        FROM topic_custom_fields tc
        WHERE tc.name = 'accepted_answer_post_id' AND
                        tc.value IS NOT NULL
        )")

    end
  end

  if Discourse.has_needed_version?(Discourse::VERSION::STRING, '1.8.0.beta6')
    require_dependency 'topic_query'

    TopicQuery.add_custom_filter(:solved) do |results, topic_query|
      if topic_query.options[:solved] == 'yes'
        results = results.where("topics.id IN (
          SELECT tc.topic_id
          FROM topic_custom_fields tc
          WHERE tc.name = 'accepted_answer_post_id' AND
                          tc.value IS NOT NULL
          )")
      elsif topic_query.options[:solved] == 'no'
        results = results.where("topics.id NOT IN (
          SELECT tc.topic_id
          FROM topic_custom_fields tc
          WHERE tc.name = 'accepted_answer_post_id' AND
                          tc.value IS NOT NULL
          )")
      end
      results
    end
  end

  require_dependency 'topic_list_item_serializer'
  require_dependency 'search_topic_list_item_serializer'
  require_dependency 'suggested_topic_serializer'
  require_dependency 'user_summary_serializer'

  class ::TopicListItemSerializer
    include TopicAnswerMixin
  end

  class ::SearchTopicListItemSerializer
    include TopicAnswerMixin
  end

  class ::SuggestedTopicSerializer
    include TopicAnswerMixin
  end

  class ::UserSummarySerializer::TopicSerializer
    include TopicAnswerMixin
  end

  class ::ListableTopicSerializer
    include TopicAnswerMixin
  end

  TopicList.preloaded_custom_fields << "accepted_answer_post_id" if TopicList.respond_to? :preloaded_custom_fields
  Site.preloaded_category_custom_fields << "enable_accepted_answers" if Site.respond_to? :preloaded_category_custom_fields
  Search.preloaded_topic_custom_fields << "accepted_answer_post_id" if Search.respond_to? :preloaded_topic_custom_fields

  if CategoryList.respond_to?(:preloaded_topic_custom_fields)
    CategoryList.preloaded_topic_custom_fields << "accepted_answer_post_id"
  end

  on(:filter_auto_bump_topics) do |_category, filters|
    filters.push(->(r) { r.where(<<~SQL)
        NOT EXISTS(
          SELECT 1 FROM topic_custom_fields
          WHERE topic_id = topics.id
          AND name = 'accepted_answer_post_id'
          AND value IS NOT NULL
        )
      SQL
    })
  end
end
