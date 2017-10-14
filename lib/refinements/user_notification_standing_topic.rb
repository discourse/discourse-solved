module DiscourseSolved
  module Refinements
    module UserNotificationStandingTopic
      refine ::UserNotifications do
        def longstanding_topic(user, opts)
          build_email(user.email,
                      template: "solved.email.long_standing_topic_notification",
                      locale: user_locale(user),
                      email_token: opts[:email_token],
                      days_since_topic_created: days_since_topic_created(opts[:topic]),
                      topic_title: opts[:topic].title,
                      topic_created_at: opts[:topic].created_at.to_date.to_s(:long)
                    )
        end

        private
        def days_since_topic_created(topic)
          (Date.today - topic.created_at.to_date).to_i
        end
      end
    end
  end
end
