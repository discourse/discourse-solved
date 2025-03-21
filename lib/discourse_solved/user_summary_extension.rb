# frozen_string_literal: true

module DiscourseSolved::UserSummaryExtension
  extend ActiveSupport::Concern

  def solved_count
    DiscourseSolved::SolvedTopic.where(accepter: @user).count
  end
end
