# frozen_string_literal: true

class DiscourseSolved::AnswerController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME

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
