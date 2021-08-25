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

  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-solved", "db", "fixtures").to_s

  [
    '../app/serializers/concerns/topic_answer_mixin.rb'
  ].each { |path| load File.expand_path(path, __FILE__) }

  skip_db = defined?(GlobalSetting.skip_db?) && GlobalSetting.skip_db?

  # we got to do a one time upgrade
  if !skip_db && defined?(UserAction::SOLVED)
    unless Discourse.redis.get('solved_already_upgraded')
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
      Discourse.redis.set("solved_already_upgraded", "true")
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

      DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
        accepted_id = topic.custom_fields["accepted_answer_post_id"].to_i

        if accepted_id > 0
          if p2 = Post.find_by(id: accepted_id)
            p2.custom_fields.delete("is_accepted_answer")
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

        notification_data = {
          message: 'solved.accepted_notification',
          display_username: acting_user.username,
          topic_title: topic.title
        }.to_json

        unless acting_user.id == post.user_id
          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: post.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
            data: notification_data
          )
        end

        if SiteSetting.notify_on_staff_accept_solved && acting_user.id != topic.user_id
          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: topic.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
            data: notification_data
          )
        end

        auto_close_hours = SiteSetting.solved_topics_auto_close_hours

        if (auto_close_hours > 0) && !topic.closed
          topic_timer = topic.set_or_create_timer(
            TopicTimer.types[:silent_close],
            nil,
            based_on_last_post: true,
            duration_minutes: auto_close_hours * 60
          )

          topic.custom_fields[
            AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD
          ] = topic_timer.id

          MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
        end

        topic.save!
        post.save!

        if WebHook.active_web_hooks(:solved).exists?
          payload = WebHook.generate_payload(:post, post)
          WebHook.enqueue_solved_hooks(:accepted_solution, post, payload)
        end

        DiscourseEvent.trigger(:accepted_solution, post)
      end
    end

    def self.unaccept_answer!(post, topic: nil)
      topic ||= post.topic

      DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
        post.custom_fields.delete("is_accepted_answer")
        topic.custom_fields.delete("accepted_answer_post_id")

        if timer_id = topic.custom_fields[AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD]
          topic_timer = TopicTimer.find_by(id: timer_id)
          topic_timer.destroy! if topic_timer
          topic.custom_fields.delete(AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD)
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

        if WebHook.active_web_hooks(:solved).exists?
          payload = WebHook.generate_payload(:post, post)
          WebHook.enqueue_solved_hooks(:unaccepted_solution, post, payload)
        end

        DiscourseEvent.trigger(:unaccepted_solution, post)
      end
    end
  end

  require_dependency "application_controller"

  class DiscourseSolved::AnswerController < ::ApplicationController

    def accept
      limit_accepts

      post = Post.find(params[:id].to_i)

      topic = post.topic
      topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

      guardian.ensure_can_accept_answer!(topic, post)

      DiscourseSolved.accept_answer!(post, current_user, topic: topic)

      render json: success_json
    end

    def unaccept
      limit_accepts

      post = Post.find(params[:id].to_i)

      topic = post.topic
      topic ||= Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

      guardian.ensure_can_accept_answer!(topic, post)

      DiscourseSolved.unaccept_answer!(post, topic: topic)
      render json: success_json
    end

    def limit_accepts
      return if current_user.staff?
      RateLimiter.new(nil, "accept-hr-#{current_user.id}", 20, 1.hour).performed!
      RateLimiter.new(nil, "accept-min-#{current_user.id}", 4, 30.seconds).performed!
    end
  end

  DiscourseSolved::Engine.routes.draw do
    post "/accept" => "answer#accept"
    post "/unaccept" => "answer#unaccept"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseSolved::Engine, at: "solution"
  end

  # TODO Drop after Discourse 2.6.0 release
  if TopicView.respond_to?(:add_post_custom_fields_allowlister)
    TopicView.add_post_custom_fields_allowlister do |user|
      ["is_accepted_answer"]
    end
  else
    TopicView.add_post_custom_fields_whitelister do |user|
      ["is_accepted_answer"]
    end
  end

  def get_schema_text(post)
    post.excerpt(nil, keep_onebox_body: true).presence || post.excerpt(nil, keep_onebox_body: true, keep_quotes: true)
  end

  def before_head_close_meta(controller)
    return "" if !controller.instance_of? TopicsController

    topic_view = controller.instance_variable_get(:@topic_view)
    topic = topic_view&.topic
    return "" if !topic
    # note, we have canonicals so we only do this for page 1 at the moment
    # it can get confusing to have this on every page and it should make page 1
    # a bit more prominent + cut down on pointless work

    return "" if SiteSetting.solved_add_schema_markup == "never"
    return "" if !controller.guardian.allow_accepted_answers_on_category?(topic.category_id)

    first_post = topic_view.posts&.first
    return "" if first_post&.post_number != 1

    question_json = {
      '@type' => 'Question',
      'name' => topic.title,
      'text' => get_schema_text(first_post),
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
        'text' => get_schema_text(accepted_answer),
        'upvoteCount' => accepted_answer.like_count,
        'dateCreated' => accepted_answer.created_at,
        'url' => accepted_answer.full_url,
        'author' => {
          '@type' => 'Person',
          'name' => accepted_answer.user&.username
        }
      }
    else
      return "" if SiteSetting.solved_add_schema_markup == "answered only"
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

      category_id, include_subcategories = report.add_category_filter
      if category_id
        if include_subcategories
          accepted_solutions = accepted_solutions.joins(:topic).where('topics.category_id IN (?)', Category.subcategory_ids(category_id))
        else
          accepted_solutions = accepted_solutions.joins(:topic).where('topics.category_id = ?', category_id)
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

  class ::WebHook
    def self.enqueue_solved_hooks(event, post, payload = nil)
      if active_web_hooks('solved').exists? && post.present?
        payload ||= WebHook.generate_payload(:post, post)

        WebHook.enqueue_hooks(:solved, event,
          id: post.id,
          category_id: post.topic&.category_id,
          tag_ids: post.topic&.tags&.pluck(:id),
          payload: payload
        )
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
        postInfo
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

    def can_accept_answer?(topic, post)
      return false if !authenticated?
      return false if !topic || !post || post.whisper?
      return false if !allow_accepted_answers_on_category?(topic.category_id)

      return true if is_staff?
      return true if current_user.trust_level >= SiteSetting.accept_all_solutions_trust_level

      if respond_to? :can_perform_action_available_to_group_moderators?
        return true if can_perform_action_available_to_group_moderators?(topic)
      end

      topic.user_id == current_user.id && !topic.closed && SiteSetting.accept_solutions_topic_author
    end
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :can_accept_answer, :can_unaccept_answer, :accepted_answer

    def can_accept_answer
      if topic = (topic_view && topic_view.topic) || object.topic
        return scope.can_accept_answer?(topic, object) && object.post_number > 1 && !accepted_answer
      end

      false
    end

    def can_unaccept_answer
      if topic = (topic_view && topic_view.topic) || object.topic
        scope.can_accept_answer?(topic, object) && (post_custom_fields["is_accepted_answer"] == 'true')
      end
    end

    def accepted_answer
      post_custom_fields["is_accepted_answer"] == 'true'
    end
  end

  require_dependency 'search'

  #TODO Remove when plugin is 1.0
  if Search.respond_to? :advanced_filter
    Search.advanced_filter(/status:solved/) do |posts|
      posts.where("topics.id IN (
        SELECT tc.topic_id
        FROM topic_custom_fields tc
        WHERE tc.name = 'accepted_answer_post_id' AND
                        tc.value IS NOT NULL
        )")

    end

    Search.advanced_filter(/status:unsolved/) do |posts|
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

  on(:before_post_publish_changes) do |post_changes, topic_changes, options|
    category_id_changes = topic_changes.diff["category_id"]
    next if category_id_changes.blank?

    old_category_allows = Guardian.new.allow_accepted_answers_on_category?(category_id_changes[0])
    new_category_allows = Guardian.new.allow_accepted_answers_on_category?(category_id_changes[1])

    options[:refresh_stream] = true if old_category_allows != new_category_allows
  end

  on(:after_populate_dev_records) do |records, type|
    next unless SiteSetting.solved_enabled

    if type == :category
      next if SiteSetting.allow_solved_on_all_topics

      solved_category = DiscourseDev::Record.random(Category.where(read_restricted: false, id: records.pluck(:id), parent_category_id: nil))
      CategoryCustomField.create!(category_id: solved_category.id, name: "enable_accepted_answers", value: "true")
      puts "discourse-solved enabled on category '#{solved_category.name}' (#{solved_category.id})."
    elsif type == :topic
      topics = Topic.where(id: records.pluck(:id))

      unless SiteSetting.allow_solved_on_all_topics
        solved_category_id = CategoryCustomField.where(name: "enable_accepted_answers", value: "true").first.category_id

        unless topics.exists?(category_id: solved_category_id)
          topics.last.update(category_id: solved_category_id)
        end

        topics = topics.where(category_id: solved_category_id)
      end

      solved_topic = DiscourseDev::Record.random(topics)
      post = nil

      if solved_topic.posts_count > 1
        post = DiscourseDev::Record.random(solved_topic.posts.where.not(post_number: 1))
      else
        post = DiscourseDev::Post.new(solved_topic, 1).create!
      end

      DiscourseSolved.accept_answer!(post, post.topic.user, topic: post.topic)
    end
  end

  query = "
    WITH x AS (SELECT
      u.id user_id,
      COUNT(DISTINCT ua.id) AS solutions
      FROM users AS u
      LEFT OUTER JOIN user_actions AS ua ON ua.user_id = u.id AND ua.action_type = #{UserAction::SOLVED} AND COALESCE(ua.created_at, :since) > :since
      WHERE u.active
        AND u.silenced_till IS NULL
        AND u.id > 0
      GROUP BY u.id
    )
    UPDATE directory_items di SET
      solutions = x.solutions
    FROM x
    WHERE x.user_id = di.user_id
    AND di.period_type = :period_type
    AND di.solutions <> x.solutions
  "
  if respond_to?(:add_directory_column)
    add_directory_column("solutions", query: query)
  end

  add_to_class(:composer_messages_finder, :check_topic_is_solved) do
    return if !SiteSetting.solved_enabled || SiteSetting.disable_solved_education_message
    return if !replying? || @topic.blank? || @topic.private_message?
    return if @topic.custom_fields["accepted_answer_post_id"].blank?

    {
      id: 'solved_topic',
      templateName: 'education',
      wait_for_typing: true,
      extraClass: 'education-message',
      hide_if_whisper: true,
      body: PrettyText.cook(I18n.t('education.topic_is_solved', base_url: Discourse.base_url))
    }
  end
end
