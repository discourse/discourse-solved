# frozen_string_literal: true

module DiscourseSolved::TopicViewSerializerExtension
  extend ActiveSupport::Concern

  prepended { attributes :accepted_answer }

  def include_accepted_answer?
    SiteSetting.solved_enabled? && object.topic.solved.present?
  end

  def accepted_answer
    accepted_answer_post_info
  end

  private

  def accepted_answer_post_info
    solved = object.topic.solved
    answer_post = solved.answer_post
    answer_post_user = answer_post.user
    accepter = solved.accepter

    excerpt =
      if SiteSetting.solved_quote_length > 0
        PrettyText.excerpt(
          answer_post.cooked,
          SiteSetting.solved_quote_length,
          keep_emoji_images: true,
        )
      else
        nil
      end

    accepted_answer = {
      post_number: answer_post.post_number,
      username: answer_post_user.username,
      name: answer_post_user.name,
      accepter_username: accepter.username,
      accepter_name: accepter.name,
      excerpt:,
    }

    if !SiteSetting.enable_names || !SiteSetting.display_name_on_posts
      accepted_answer[:name] = nil
      accepted_answer[:accepter_name] = nil
    end

    accepted_answer
  end
end
