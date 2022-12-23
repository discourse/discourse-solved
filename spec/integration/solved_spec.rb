# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Managing Posts solved status" do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:trust_level_4) }
  let(:p1) { Fabricate(:post, topic: topic) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe "auto bump" do
    it "does not automatically bump solved topics" do
      category = Fabricate(:category_with_definition)

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

  describe "accepting a post as the answer" do
    before do
      sign_in(user)
      SiteSetting.solved_topics_auto_close_hours = 2
    end

    it "can mark a post as the accepted answer correctly" do
      freeze_time

      post "/solution/accept.json", params: { id: p1.id }

      expect(response.status).to eq(200)
      expect(p1.reload.custom_fields["is_accepted_answer"]).to eq("true")

      topic.reload

      expect(topic.public_topic_timer.status_type).to eq(TopicTimer.types[:silent_close])

      expect(topic.custom_fields[DiscourseSolved::AUTO_CLOSE_TOPIC_TIMER_CUSTOM_FIELD].to_i).to eq(
        topic.public_topic_timer.id,
      )

      expect(topic.public_topic_timer.execute_at).to eq_time(Time.zone.now + 2.hours)

      expect(topic.public_topic_timer.based_on_last_post).to eq(true)
    end

    it "sends notifications to correct users" do
      SiteSetting.notify_on_staff_accept_solved = true
      user = Fabricate(:user)
      topic = Fabricate(:topic, user: user)
      post = Fabricate(:post, post_number: 2, topic: topic)

      op = topic.user
      user = post.user

      expect { DiscourseSolved.accept_answer!(post, Discourse.system_user) }.to change {
        user.notifications.count
      }.by(1) & change { op.notifications.count }.by(1)

      notification = user.notifications.last
      expect(notification.notification_type).to eq(Notification.types[:custom])
      expect(notification.topic_id).to eq(post.topic_id)
      expect(notification.post_number).to eq(post.post_number)

      notification = op.notifications.last
      expect(notification.notification_type).to eq(Notification.types[:custom])
      expect(notification.topic_id).to eq(post.topic_id)
      expect(notification.post_number).to eq(post.post_number)
    end

    it "does not set a timer when the topic is closed" do
      topic.update!(closed: true)
      post "/solution/accept.json", params: { id: p1.id }

      expect(response.status).to eq(200)

      p1.reload
      topic.reload

      expect(p1.custom_fields["is_accepted_answer"]).to eq("true")
      expect(topic.public_topic_timer).to eq(nil)
      expect(topic.closed).to eq(true)
    end

    it "works with staff and trashed topics" do
      topic.trash!(Discourse.system_user)

      post "/solution/accept.json", params: { id: p1.id }
      expect(response.status).to eq(403)

      sign_in(Fabricate(:admin))
      post "/solution/accept.json", params: { id: p1.id }
      expect(response.status).to eq(200)

      p1.reload
      expect(p1.custom_fields["is_accepted_answer"]).to eq("true")
    end

    it "does not allow you to accept a whisper" do
      whisper = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      sign_in(Fabricate(:admin))

      post "/solution/accept.json", params: { id: whisper.id }
      expect(response.status).to eq(403)
    end

    it "triggers a webhook" do
      Fabricate(:solved_web_hook)
      post "/solution/accept.json", params: { id: p1.id }

      job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

      expect(job_args["event_name"]).to eq("accepted_solution")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(p1.id)
    end
  end

  describe "#unaccept" do
    before { sign_in(user) }

    describe "when solved_topics_auto_close_hours is enabled" do
      before do
        SiteSetting.solved_topics_auto_close_hours = 2
        DiscourseSolved.accept_answer!(p1, user)
      end

      it "should unmark the post as solved" do
        expect do post "/solution/unaccept.json", params: { id: p1.id } end.to change {
          topic.reload.public_topic_timer
        }.to(nil)

        expect(response.status).to eq(200)
        p1.reload

        expect(p1.custom_fields["is_accepted_answer"]).to eq(nil)
        expect(p1.topic.custom_fields["accepted_answer_post_id"]).to eq(nil)
      end
    end

    it "triggers a webhook" do
      Fabricate(:solved_web_hook)
      post "/solution/unaccept.json", params: { id: p1.id }

      job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

      expect(job_args["event_name"]).to eq("unaccepted_solution")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(p1.id)
    end
  end

  context "with group moderators" do
    fab!(:group_user) { Fabricate(:group_user) }
    let(:user_gm) { group_user.user }
    let(:group) { group_user.group }

    before do
      SiteSetting.enable_category_group_moderation = true
      p1.topic.category.update!(reviewable_by_group_id: group.id)
      sign_in(user_gm)
    end

    it "can accept a solution" do
      post "/solution/accept.json", params: { id: p1.id }
      expect(response.status).to eq(200)
    end
  end
end
