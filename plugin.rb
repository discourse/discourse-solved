# name: discourse-solved
# about: Add a solved button to answers on Discourse
# version: 0.1
# authors: Sam Saffron

PLUGIN_NAME = "discourse_solved".freeze

register_asset 'stylesheets/solutions.scss'

after_initialize do

  module ::DiscourseSolved
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSolved
    end
  end

  require_dependency "application_controller"
  class DiscourseSolved::AnswerController < ::ApplicationController
    def accept
      post = Post.find(params[:id].to_i)

      guardian.ensure_can_accept_answer!(post.topic)

      accepted_id = post.topic.custom_fields["accepted_answer_post_id"].to_i
      if accepted_id > 0
        if p2 = Post.find_by(id: accepted_id)
          p2.custom_fields["is_accepted_answer"] = nil
          p2.save!
        end
      end

      post.custom_fields["is_accepted_answer"] = "true"
      post.topic.custom_fields["accepted_answer_post_id"] = post.id
      post.topic.save!
      post.save!

      unless current_user.id == post.user_id

        Notification.create!(notification_type: Notification.types[:custom],
                           user_id: post.user_id,
                           topic_id: post.topic_id,
                           post_number: post.post_number,
                           data: {
                             message: 'solved.accepted_notification',
                             display_username: current_user.username,
                             topic_title: post.topic.title
                           }.to_json
                          )
      end

      render json: success_json
    end

    def unaccept
      post = Post.find(params[:id].to_i)

      guardian.ensure_can_accept_answer!(post.topic)

      post.custom_fields["is_accepted_answer"] = nil
      post.topic.custom_fields["accepted_answer_post_id"] = nil
      post.topic.save!
      post.save!

      render json: success_json
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
        }
      end
    end

    def accepted_answer_post_info
      # TODO: we may already have it in the stream ... so bypass query here

      Post.where(id: accepted_answer_post_id, topic_id: object.topic.id)
          .joins(:user)
          .pluck('post_number, username')
          .first
    end

    def accepted_answer_post_id
      id = object.topic.custom_fields["accepted_answer_post_id"]
      id && id.to_i
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
      self.class.reset_accepted_answer_cache unless @@allowed_accepted_cache["allowed"]
      @@allowed_accepted_cache["allowed"].include?(category_id)
    end

    def can_accept_answer?(topic)
      allow_accepted_answers_on_category?(topic.category_id) && (
        is_staff? || (
          authenticated? && !topic.closed? && topic.user_id == current_user.id
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
        scope.can_accept_answer?(topic) &&
        object.post_number > 1 && !accepted_answer
      end
    end

    def can_unaccept_answer
      topic = (topic_view && topic_view.topic) || object.topic
      if topic
        scope.can_accept_answer?(topic) && post_custom_fields["is_accepted_answer"]
      end
    end

    def accepted_answer
      post_custom_fields["is_accepted_answer"]
    end

  end
end
