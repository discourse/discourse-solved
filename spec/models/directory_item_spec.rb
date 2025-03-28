# frozen_string_literal: true

describe DirectoryItem, type: :model do
  describe "Updating user directory with solutions count" do
    fab!(:user)
    fab!(:admin)

    fab!(:topic1) { Fabricate(:topic, archetype: "regular", user:) }
    fab!(:topic_post1) { Fabricate(:post, topic: topic1, user:) }

    fab!(:topic2) { Fabricate(:topic, archetype: "regular", user:) }
    fab!(:topic_post2) { Fabricate(:post, topic: topic2, user:) }

    fab!(:pm) { Fabricate(:topic, archetype: "private_message", user:, category_id: nil) }
    fab!(:pm_post) { Fabricate(:post, topic: pm, user:) }

    before { SiteSetting.solved_enabled = true }

    it "excludes PM post solutions from solutions" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      DiscourseSolved.accept_answer!(pm_post, admin)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end

    it "excludes deleted posts from solutions" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      DiscourseSolved.accept_answer!(topic_post2, admin)
      topic_post2.update(deleted_at: Time.zone.now)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end

    it "excludes deleted topics from solutions" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      DiscourseSolved.accept_answer!(topic_post2, admin)
      topic2.update(deleted_at: Time.zone.now)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end

    it "excludes solutions for silenced users" do
      user.update(silenced_till: Time.zone.now + 1.day)

      DiscourseSolved.accept_answer!(topic_post1, admin)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        )&.solutions,
      ).to eq(nil)
    end

    it "excludes solutions for suspended users" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      user.update(suspended_till: Time.zone.now + 1.day)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        )&.solutions,
      ).to eq(0)
    end

    it "includes solutions for active users" do
      DiscourseSolved.accept_answer!(topic_post1, admin)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end
  end
end
