# frozen_string_literal: true

require "rails_helper"

describe DiscourseSolved::GuardianExtensions do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: other_user) }

  let(:guardian) { user.guardian }

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe ".can_accept_answer?" do
    it "returns false for anon users" do
      expect(Guardian.new.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns false if the topic is nil, the post is nil, or for whispers" do
      expect(guardian.can_accept_answer?(nil, post)).to eq(false)
      expect(guardian.can_accept_answer?(topic, nil)).to eq(false)

      post.update!(post_type: Post.types[:whisper])
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns false if accepted answers are not allowed" do
      SiteSetting.allow_solved_on_all_topics = false
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns true for admins" do
      expect(
        Guardian.new(Fabricate(:admin, refresh_auto_groups: true)).can_accept_answer?(topic, post),
      ).to eq(true)
    end

    it "returns true if the user has the correct trust level" do
      SiteSetting.accept_all_solutions_trust_level = TrustLevel[0]
      expect(guardian.can_accept_answer?(topic, post)).to eq(true)
      SiteSetting.accept_all_solutions_trust_level = TrustLevel[4]
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns true if the user is a category group moderator for the topic" do
      group = Fabricate(:group)
      group.add(user)
      category = Fabricate(:category, reviewable_by_group_id: group.id)
      topic.update!(category: category)
      SiteSetting.enable_category_group_moderation = true
      expect(guardian.can_accept_answer?(topic, post)).to eq(true)
    end

    it "returns true if the user is the topic author for an open topic" do
      SiteSetting.accept_solutions_topic_author = true
      topic.update!(user: user)
      expect(guardian.can_accept_answer?(topic, post)).to eq(true)
    end
  end
end
