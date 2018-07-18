require 'rails_helper'

RSpec.describe "Managing Posts solved status" do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:trust_level_4) }
  let(:p1) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.allow_solved_on_all_topics = true
  end

  describe 'auto bump' do
    it 'does not automatically bump solved topics' do
      category = Fabricate(:category)

      post = create_post(category: category)
      post2 = create_post(category: category)

      DiscourseSolved.accept_answer!(post, Discourse.system_user)

      category.num_auto_bump_daily = 2
      category.save!

      freeze_time 1.month.from_now

      expect(category.auto_bump_topic!).to eq(true)

      freeze_time 13.hours.from_now

      expect(category.auto_bump_topic!).to eq(false)

      expect(post.topic.reload.posts_count).to eq(1)
      expect(post2.topic.reload.posts_count).to eq(2)
    end
  end

  describe 'accepting a post as the answer' do
    before do
      sign_in(user)
      SiteSetting.solved_topics_auto_close_hours = 2
    end

    it 'can mark a post as the accepted answer correctly' do
      post "/solution/accept.json", params: { id: p1.id }

      expect(p1.reload.custom_fields["is_accepted_answer"]).to eq("true")

      expect(topic.public_topic_timer.status_type).to eq(TopicTimer.types[:close])

      expect(topic.public_topic_timer.execute_at)
        .to be_within(1.second).of(Time.zone.now + 2.hours)

      expect(topic.public_topic_timer.based_on_last_post).to eq(true)
    end
    it 'does not set a timer when the topic is closed' do
      topic.update!(closed: true)
      post "/solution/accept.json", params: { id: p1.id }
      p1.reload
      topic.reload

      expect(p1.custom_fields["is_accepted_answer"]).to eq("true")
      expect(topic.public_topic_timer).to eq(nil)
      expect(topic.closed).to eq(true)
    end
  end
end
