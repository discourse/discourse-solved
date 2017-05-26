require 'rails_helper'

RSpec.describe "Managing Posts solved status" do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:trust_level_4) }
  let(:p1) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.allow_solved_on_all_topics = true
  end

  describe 'accepting a post as the answer' do
    before do
      sign_in(user)
      SiteSetting.solved_topics_auto_close_hours = 2
    end

    it 'can mark a post as the accepted answer correctly' do
      xhr :post, "/solution/accept", id: p1.id

      expect(p1.reload.custom_fields["is_accepted_answer"]).to eq("true")

      expect(topic.public_topic_timer.status_type).to eq(TopicTimer.types[:close])

      expect(topic.public_topic_timer.execute_at)
        .to be_within(1.second).of(Time.zone.now + 2.hours)

      expect(topic.public_topic_timer.based_on_last_post).to eq(true)
    end
  end
end
