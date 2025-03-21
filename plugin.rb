# frozen_string_literal: true

# name: discourse-solved
# about: Allows users to accept solutions on topics in designated categories.
# meta_topic_id: 30155
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-solved

enabled_site_setting :solved_enabled

register_svg_icon "far-square-check"
register_svg_icon "square-check"
register_svg_icon "far-square"

register_asset "stylesheets/solutions.scss"
register_asset "stylesheets/mobile/solutions.scss", :mobile

module ::DiscourseSolved
  PLUGIN_NAME = "discourse-solved"
  AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD = "solved_auto_close_topic_timer_id"
  ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD = "accepted_answer_post_id"
  ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD = "enable_accepted_answers"
  IS_ACCEPTED_ANSWER_CUSTOM_FIELD = "is_accepted_answer"
end

require_relative "lib/discourse_solved/engine.rb"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-solved", "db", "fixtures").to_s

  module ::DiscourseSolved
    def self.accept_answer!(post, acting_user, topic: nil)
      topic ||= post.topic

      DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
        accepted_id = topic.custom_fields[ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD].to_i

        if accepted_id > 0
          if p2 = Post.find_by(id: accepted_id)
            p2.custom_fields.delete(IS_ACCEPTED_ANSWER_CUSTOM_FIELD)
            p2.save!

            UserAction.where(action_type: UserAction::SOLVED, target_post_id: p2.id).destroy_all
          end
        end

        post.custom_fields[IS_ACCEPTED_ANSWER_CUSTOM_FIELD] = "true"
        topic.custom_fields[ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD] = post.id

        UserAction.log_action!(
          action_type: UserAction::SOLVED,
          user_id: post.user_id,
          acting_user_id: acting_user.id,
          target_post_id: post.id,
          target_topic_id: post.topic_id,
        )

        notification_data = {
          message: "solved.accepted_notification",
          display_username: acting_user.username,
          topic_title: topic.title,
          title: "solved.notification.title",
        }.to_json

        unless acting_user.id == post.user_id
          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: post.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
            data: notification_data,
          )
        end

        if SiteSetting.notify_on_staff_accept_solved && acting_user.id != topic.user_id
          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: topic.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
            data: notification_data,
          )
        end

        auto_close_hours = 0
        if topic&.category.present?
          auto_close_hours = topic.category.custom_fields["solved_topics_auto_close_hours"].to_i
          auto_close_hours = 175_200 if auto_close_hours > 175_200 # 20 years
        end

        auto_close_hours = SiteSetting.solved_topics_auto_close_hours if auto_close_hours == 0

        if (auto_close_hours > 0) && !topic.closed
          topic_timer =
            topic.set_or_create_timer(
              TopicTimer.types[:silent_close],
              nil,
              based_on_last_post: true,
              duration_minutes: auto_close_hours * 60,
            )

          topic.custom_fields[AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD] = topic_timer.id

          MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
        end

        topic.save!
        post.save!

        if WebHook.active_web_hooks(:accepted_solution).exists?
          payload = WebHook.generate_payload(:post, post)
          WebHook.enqueue_solved_hooks(:accepted_solution, post, payload)
        end

        DiscourseEvent.trigger(:accepted_solution, post)
      end
    end

    def self.unaccept_answer!(post, topic: nil)
      topic ||= post.topic
      topic ||= Topic.unscoped.find_by(id: post.topic_id)

      return if topic.nil?

      DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
        post.custom_fields.delete(IS_ACCEPTED_ANSWER_CUSTOM_FIELD)
        topic.custom_fields.delete(ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD)

        if timer_id = topic.custom_fields[AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD]
          topic_timer = TopicTimer.find_by(id: timer_id)
          topic_timer.destroy! if topic_timer
          topic.custom_fields.delete(AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD)
        end

        topic.save!
        post.save!

        # TODO remove_action! does not allow for this type of interface
        UserAction.where(action_type: UserAction::SOLVED, target_post_id: post.id).destroy_all

        # yank notification
        notification =
          Notification.find_by(
            notification_type: Notification.types[:custom],
            user_id: post.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
          )

        notification.destroy! if notification

        if WebHook.active_web_hooks(:unaccepted_solution).exists?
          payload = WebHook.generate_payload(:post, post)
          WebHook.enqueue_solved_hooks(:unaccepted_solution, post, payload)
        end

        DiscourseEvent.trigger(:unaccepted_solution, post)
      end
    end

    def self.skip_db?
      defined?(GlobalSetting.skip_db?) && GlobalSetting.skip_db?
    end
  end

  reloadable_patch do
    ::Guardian.prepend(DiscourseSolved::GuardianExtensions)
    ::WebHook.prepend(DiscourseSolved::WebHookExtension)
    ::TopicViewSerializer.prepend(DiscourseSolved::TopicViewSerializerExtension)
    ::Category.prepend(DiscourseSolved::CategoryExtension)
    ::PostSerializer.prepend(DiscourseSolved::PostSerializerExtension)
    ::UserSummary.prepend(DiscourseSolved::UserSummaryExtension)
    ::Topic.attr_accessor(:accepted_answer_user_id)
    ::TopicPostersSummary.alias_method(:old_user_ids, :user_ids)
    ::TopicPostersSummary.prepend(DiscourseSolved::TopicPostersSummaryExtension)
    [
      ::TopicListItemSerializer,
      ::SearchTopicListItemSerializer,
      ::SuggestedTopicSerializer,
      ::UserSummarySerializer::TopicSerializer,
      ::ListableTopicSerializer,
    ].each { |klass| klass.include(DiscourseSolved::TopicAnswerMixin) }
  end

  # we got to do a one time upgrade
  if !::DiscourseSolved.skip_db?
    unless Discourse.redis.get("solved_already_upgraded")
      unless UserAction.where(action_type: UserAction::SOLVED).exists?
        Rails.logger.info("Upgrading storage for solved")
        sql = <<~SQL
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

  topic_view_post_custom_fields_allowlister { [::DiscourseSolved::IS_ACCEPTED_ANSWER_CUSTOM_FIELD] }
  TopicList.preloaded_custom_fields << ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD
  Site.preloaded_category_custom_fields << ::DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD
  Search.preloaded_topic_custom_fields << ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD
  CategoryList.preloaded_topic_custom_fields << ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD

  add_api_key_scope(
    :solved,
    { answer: { actions: %w[discourse_solved/answer#accept discourse_solved/answer#unaccept] } },
  )

  register_html_builder("server:before-head-close-crawler") do |controller|
    DiscourseSolved::BeforeHeadClose.new(controller).html
  end

  register_html_builder("server:before-head-close") do |controller|
    DiscourseSolved::BeforeHeadClose.new(controller).html
  end

  Report.add_report("accepted_solutions") do |report|
    report.data = []

    accepted_solutions =
      TopicCustomField
        .joins(:topic)
        .where("topics.archetype <> ?", Archetype.private_message)
        .where(name: ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD)

    category_id, include_subcategories = report.add_category_filter
    if category_id
      if include_subcategories
        accepted_solutions =
          accepted_solutions.where(
            "topics.category_id IN (?)",
            Category.subcategory_ids(category_id),
          )
      else
        accepted_solutions = accepted_solutions.where("topics.category_id = ?", category_id)
      end
    end

    accepted_solutions
      .where("topic_custom_fields.created_at >= ?", report.start_date)
      .where("topic_custom_fields.created_at <= ?", report.end_date)
      .group("DATE(topic_custom_fields.created_at)")
      .order("DATE(topic_custom_fields.created_at)")
      .count
      .each { |date, count| report.data << { x: date, y: count } }
    report.total = accepted_solutions.count
    report.prev30Days =
      accepted_solutions
        .where("topic_custom_fields.created_at >= ?", report.start_date - 30.days)
        .where("topic_custom_fields.created_at <= ?", report.start_date)
        .count
  end

  register_modifier(:search_rank_sort_priorities) do |priorities, _search|
    if SiteSetting.prioritize_solved_topics_in_search
      condition = <<~SQL
        EXISTS (
          SELECT 1
            FROM topic_custom_fields
           WHERE topic_id = topics.id
             AND name = '#{::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD}'
             AND value IS NOT NULL
        )
      SQL

      priorities.push([condition, 1.1])
    else
      priorities
    end
  end

  register_modifier(:user_action_stream_builder) do |builder|
    builder.where("t.deleted_at IS NULL").where("t.archetype <> ?", Archetype.private_message)
  end

  add_to_serializer(:user_card, :accepted_answers) do
    UserAction
      .where(user_id: object.id)
      .where(action_type: UserAction::SOLVED)
      .joins("JOIN topics ON topics.id = user_actions.target_topic_id")
      .where("topics.archetype <> ?", Archetype.private_message)
      .where("topics.deleted_at IS NULL")
      .count
  end
  add_to_serializer(:user_summary, :solved_count) { object.solved_count }
  add_to_serializer(:post, :can_accept_answer) do
    scope.can_accept_answer?(topic, object) && object.post_number > 1 && !accepted_answer
  end
  add_to_serializer(:post, :can_unaccept_answer) do
    scope.can_accept_answer?(topic, object) && accepted_answer
  end
  add_to_serializer(:post, :accepted_answer) do
    post_custom_fields[::DiscourseSolved::IS_ACCEPTED_ANSWER_CUSTOM_FIELD] == "true"
  end
  add_to_serializer(:post, :topic_accepted_answer) do
    topic&.custom_fields&.[](::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD).present?
  end

  on(:post_destroyed) do |post|
    if post.custom_fields[::DiscourseSolved::IS_ACCEPTED_ANSWER_CUSTOM_FIELD] == "true"
      ::DiscourseSolved.unaccept_answer!(post)
    end
  end

  on(:filter_auto_bump_topics) do |_category, filters|
    filters.push(
      ->(r) do
        sql = <<~SQL
          NOT EXISTS (
            SELECT 1
              FROM topic_custom_fields
             WHERE topic_id = topics.id
               AND name = '#{::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD}'
               AND value IS NOT NULL
          )
        SQL

        r.where(sql)
      end,
    )
  end

  on(:before_post_publish_changes) do |post_changes, topic_changes, options|
    category_id_changes = topic_changes.diff["category_id"].to_a
    tag_changes = topic_changes.diff["tags"].to_a

    old_allowed = Guardian.new.allow_accepted_answers?(category_id_changes[0], tag_changes[0])
    new_allowed = Guardian.new.allow_accepted_answers?(category_id_changes[1], tag_changes[1])

    options[:refresh_stream] = true if old_allowed != new_allowed
  end

  query = <<~SQL
    WITH x AS (
      SELECT u.id user_id, COUNT(DISTINCT ua.id) AS solutions
      FROM users AS u
      LEFT JOIN user_actions AS ua
         ON ua.user_id = u.id
        AND ua.action_type = #{UserAction::SOLVED}
        AND COALESCE(ua.created_at, :since) > :since
      JOIN topics AS t
         ON t.id = ua.target_topic_id
        AND t.archetype <> 'private_message'
        AND t.deleted_at IS NULL
      JOIN posts AS p
         ON p.id = ua.target_post_id
        AND p.deleted_at IS NULL
      WHERE u.id > 0
        AND u.active
        AND u.silenced_till IS NULL
        AND u.suspended_till IS NULL
      GROUP BY u.id
    )
    UPDATE directory_items di
    SET solutions = x.solutions
    FROM x
    WHERE x.user_id = di.user_id
      AND di.period_type = :period_type
      AND di.solutions <> x.solutions
  SQL

  add_directory_column("solutions", query:)

  add_to_class(:composer_messages_finder, :check_topic_is_solved) do
    return if !SiteSetting.solved_enabled || SiteSetting.disable_solved_education_message
    return if !replying? || @topic.blank? || @topic.private_message?
    return if @topic.custom_fields[::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD].blank?

    {
      id: "solved_topic",
      templateName: "education",
      wait_for_typing: true,
      extraClass: "education-message",
      hide_if_whisper: true,
      body: PrettyText.cook(I18n.t("education.topic_is_solved", base_url: Discourse.base_url)),
    }
  end

  register_topic_list_preload_user_ids do |topics, user_ids, topic_list|
    answer_post_ids =
      TopicCustomField
        .select("value::INTEGER")
        .where(name: ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD)
        .where(topic_id: topics.map(&:id))
    answer_user_ids = Post.where(id: answer_post_ids).pluck(:topic_id, :user_id).to_h
    topics.each { |topic| topic.accepted_answer_user_id = answer_user_ids[topic.id] }
    user_ids.concat(answer_user_ids.values)
  end

  DiscourseSolved::RegisterFilters.register(self)

  DiscourseDev::DiscourseSolved.populate(self)
  DiscourseAutomation::EntryPoint.inject(self) if defined?(DiscourseAutomation)
  DiscourseAssign::EntryPoint.inject(self) if defined?(DiscourseAssign)
end
