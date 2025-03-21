# frozen_string_literal: true

require_relative "../../db/migrate/20250318024953_copy_solved_topic_custom_field_to_discourse_solved_solved_topics"

module DiscourseSolved
  describe CopySolvedTopicCustomFieldToDiscourseSolvedSolvedTopics do
    let(:migration) { described_class.new }

    it "copies accepted answer from custom fields to table" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic)
      acting_user = Fabricate(:user)

      TopicCustomField.create!(
        topic: topic,
        name: "accepted_answer_post_id",
        value: post.id.to_s,
        created_at: 1.day.ago,
        updated_at: 1.day.ago,
      )
      TopicCustomField.create!(topic: topic, name: "solved_auto_close_topic_timer_id", value: "123")
      UserAction.create!(
        action_type: 15,
        user_id: acting_user.id,
        acting_user_id: acting_user.id,
        target_topic_id: topic.id,
        created_at: 1.hour.ago,
      )

      migration.up

      solved_topic = DiscourseSolved::SolvedTopic.last
      expect(solved_topic.topic_id).to eq(topic.id)
      expect(solved_topic.answer_post_id).to eq(post.id)
      expect(solved_topic.topic_timer_id).to eq(123)
      expect(solved_topic.accepter_user_id).to eq(acting_user.id)
    end

    it "uses the most recent user action for accepter" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic)
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      TopicCustomField.create!(topic: topic, name: "accepted_answer_post_id", value: post.id.to_s)
      UserAction.create!(
        action_type: 15,
        user_id: user1.id,
        acting_user_id: user1.id,
        target_topic_id: topic.id,
        created_at: 2.hours.ago,
      )
      UserAction.create!(
        action_type: 15,
        user_id: user2.id,
        acting_user_id: user2.id,
        target_topic_id: topic.id,
        created_at: 1.hour.ago,
      )

      migration.up

      expect(DiscourseSolved::SolvedTopic.last.accepter_user_id).to eq(user2.id)
    end
  end
end
