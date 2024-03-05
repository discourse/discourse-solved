# frozen_string_literal: true

module DiscourseSolved::UserSummaryExtension
  extend ActiveSupport::Concern

  def solved_count
    UserAction.where(user: @user).where(action_type: UserAction::SOLVED).count
  end
end
