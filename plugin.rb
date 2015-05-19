# name: discourse-solved-button
# about: Add a solved button to answers on Discourse
# version: 0.1
# authors: Sam Saffron

PLUGIN_NAME = "discourse_solved_button".freeze

register_asset 'stylesheets/solutions.scss'

after_initialize do

  module ::DiscourseSolvedButton
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSolvedButton
    end
  end

  require_dependency "application_controller"
  class DiscourseSolvedButton::AnswerController < ::ApplicationController
    def accept

      post = Post.find(params[:id].to_i)

      accepted_id = post.topic.custom_fields["has_accepted_answer"].to_i
      if accepted_id
        if p2 = Post.find_by(id: accepted_id)
          p2.custom_fields["is_accepted_answer"] = nil
          p2.save!
        end
      end

      post.custom_fields["is_accepted_answer"] = "true"
      post.topic.custom_fields["accepted_answer_post_id"] = post.id
      post.topic.save!
      post.save!

      render json: success_json
    end

    def unaccept
      post = Post.find(params[:id].to_i)
      post.custom_fields["is_accepted_answer"] = nil
      post.topic.custom_fields["accepted_answer_post_id"] = nil
      post.topic.save!
      post.save!

      render json: success_json
    end
  end

  DiscourseSolvedButton::Engine.routes.draw do
    post "/accept" => "answer#accept"
    post "/unaccept" => "answer#unaccept"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseSolvedButton::Engine, at: "solution"
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

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :can_accept_answer, :can_unaccept_answer, :accepted_answer

    def can_accept_answer
      topic = (topic_view && topic_view.topic) || object.topic
      if topic
        object.post_number > 1 && !accepted_answer
      end
    end

    def can_unaccept_answer
      post_custom_fields["is_accepted_answer"]
    end

    def accepted_answer
      post_custom_fields["is_accepted_answer"]
    end

  end
end
