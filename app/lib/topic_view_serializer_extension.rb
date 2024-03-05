# frozen_string_literal: true

module DiscourseSolved::TopicViewSerializerExtension
  extend ActiveSupport::Concern

  prepended { attributes :accepted_answer }

  def include_accepted_answer?
    SiteSetting.solved_enabled? && accepted_answer_post_id
  end

  def accepted_answer
    if info = accepted_answer_post_info
      { post_number: info[0], username: info[1], excerpt: info[2], name: info[3] }
    end
  end

  private

  def accepted_answer_post_info
    post_info =
      if post = object.posts.find { |p| p.post_number == accepted_answer_post_id }
        [post.post_number, post.user.username, post.cooked, post.user.name]
      else
        Post
          .where(id: accepted_answer_post_id, topic_id: object.topic.id)
          .joins(:user)
          .pluck("post_number", "username", "cooked", "name")
          .first
      end

    if post_info
      post_info[2] = if SiteSetting.solved_quote_length > 0
        PrettyText.excerpt(post_info[2], SiteSetting.solved_quote_length, keep_emoji_images: true)
      else
        nil
      end

      post_info[3] = nil if !SiteSetting.enable_names || !SiteSetting.display_name_on_posts

      post_info
    end
  end

  def accepted_answer_post_id
    id = object.topic.custom_fields[::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD]
    # a bit messy but race conditions can give us an array here, avoid
    begin
      id && id.to_i
    rescue StandardError
      nil
    end
  end
end
