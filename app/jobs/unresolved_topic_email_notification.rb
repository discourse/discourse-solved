load File.expand_path("../../../lib/refinements/user_notification_standing_topic.rb", __FILE__)

module Jobs
  class UnresolvedTopicEmailNotification < ::Jobs::Scheduled
    using DiscourseSolved::Refinements::UserNotificationStandingTopic

    every 1.day
    def execute(args)
      puts "email notification #{email_notification_enabled}"
      if email_notification_enabled
        unresolved_topics = Topic.joins(:category, :_custom_fields, category: :_custom_fields ).
          where(
            topic_custom_fields: {
              name: 'accepted_answer_post_id',
              value: nil
            },
            category_custom_fields: {
              name: 'enable_accepted_answers',
              value: 'true'
            }
          ).where(
            "topics.created_at <= ?::date + '1 day'::interval",
            Date.today - SiteSetting.solved_email_notification_delay.days
          )
          puts unresolved_topics
          unresolved_topics.each do |topic|
            begin
              email = UserNotifications.new.longstanding_topic(topic.user, { topic: topic })
              email.deliver
            rescue Exception => e
            end
          end
      end
    end

    def email_notification_enabled
      SiteSetting.solved_email_notification_delay > 0 && SiteSetting.solved_enabled
    end
  end
end
