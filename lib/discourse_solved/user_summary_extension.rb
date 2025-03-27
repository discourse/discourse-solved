# frozen_string_literal: true

module DiscourseSolved::UserSummaryExtension
  extend ActiveSupport::Concern

  def solved_count
    DiscourseSolved::SolvedTopic
      .joins("JOIN posts ON posts.id = discourse_solved_solved_topics.answer_post_id")
      .where(posts: { user_id: @user.id })
      .count
  end
end
