# frozen_string_literal: true

describe UserSummary do
  describe "solved_count" do
    it "indicates the number of times a user's post is a topic's solution" do
      topic = Fabricate(:topic)
      Fabricate(:post, topic:)
      user = Fabricate(:user)
      admin = Fabricate(:admin)
      post = Fabricate(:post, topic:, user:)

      user_summary = UserSummary.new(user, Guardian.new)
      admin_summary = UserSummary.new(admin, Guardian.new)

      expect(user_summary.solved_count).to eq(0)
      expect(admin_summary.solved_count).to eq(0)

      DiscourseSolved.accept_answer!(post, admin)

      expect(user_summary.solved_count).to eq(1)
      expect(admin_summary.solved_count).to eq(0)
    end
  end
end
