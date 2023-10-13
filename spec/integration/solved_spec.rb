# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Managing Posts solved status" do
  let(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:trust_level_4) }
  let(:p1) { Fabricate(:post, topic: topic) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe "search" do
    before { SearchIndexer.enable }

    after { SearchIndexer.disable }

    it "can prioritize solved topics in search" do
      normal_post =
        Fabricate(
          :post,
          raw: "My reply carrot",
          topic: Fabricate(:topic, title: "A topic that is not solved but open"),
        )

      solved_post =
        Fabricate(
          :post,
          raw: "My solution carrot",
          topic: Fabricate(:topic, title: "A topic that will be closed", closed: true),
        )

      DiscourseSolved.accept_answer!(solved_post, Discourse.system_user)

      result = Search.execute("carrot")
      expect(result.posts.pluck(:id)).to eq([normal_post.id, solved_post.id])

      SiteSetting.prioritize_solved_topics_in_search = true

      result = Search.execute("carrot")
      expect(result.posts.pluck(:id)).to eq([solved_post.id, normal_post.id])
    end

    describe "#advanced_search" do
      fab!(:category_enabled) do
        category = Fabricate(:category)
        category_custom_field =
          CategoryCustomField.new(
            category_id: category.id,
            name: ::DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
            value: "true",
          )
        category_custom_field.save
        category
      end
      fab!(:category_disabled) do
        category = Fabricate(:category)
        category_custom_field =
          CategoryCustomField.new(
            category_id: category.id,
            name: ::DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
            value: "false",
          )
        category_custom_field.save
        category
      end
      fab!(:topic_unsolved) do
        Fabricate(
          :custom_topic,
          user: user,
          category: category_enabled,
          custom_topic_name: ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD,
        )
      end
      fab!(:topic_solved) do
        Fabricate(
          :custom_topic,
          user: user,
          category: category_enabled,
          custom_topic_name: ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD,
        )
      end
      fab!(:topic_disabled_1) do
        Fabricate(
          :custom_topic,
          user: user,
          category: category_disabled,
          custom_topic_name: ::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD,
        )
      end
      fab!(:topic_disabled_2) do
        Fabricate(
          :custom_topic,
          user: user,
          category: category_disabled,
          custom_topic_name: "another_custom_field",
        )
      end
      fab!(:post_unsolved) { Fabricate(:post, topic: topic_unsolved) }
      fab!(:post_solved) do
        post = Fabricate(:post, topic: topic_solved)
        DiscourseSolved.accept_answer!(post, Discourse.system_user)
        post
      end
      fab!(:post_disabled_1) { Fabricate(:post, topic: topic_disabled_1) }
      fab!(:post_disabled_2) { Fabricate(:post, topic: topic_disabled_2) }

      before do
        SearchIndexer.enable
        Jobs.run_immediately!

        SearchIndexer.index(topic_unsolved, force: true)
        SearchIndexer.index(topic_solved, force: true)
        SearchIndexer.index(topic_disabled_1, force: true)
        SearchIndexer.index(topic_disabled_2, force: true)
      end

      after { SearchIndexer.disable }

      describe "searches for unsolved topics" do
        describe "when allow solved on all topics is disabled" do
          before { SiteSetting.allow_solved_on_all_topics = false }

          it "only returns posts where 'Allow topic owner and staff to mark a reply as the solution' is enabled and post is not solved" do
            result = Search.execute("status:unsolved")
            expect(result.posts.pluck(:id)).to match_array([post_unsolved.id])
          end
        end
        describe "when allow solved on all topics is enabled" do
          before { SiteSetting.allow_solved_on_all_topics = true }
          it "only returns posts where the post is not solved" do
            result = Search.execute("status:unsolved")
            expect(result.posts.pluck(:id)).to match_array(
              [post_unsolved.id, post_disabled_1.id, post_disabled_2.id],
            )
          end
        end
      end
    end
  end

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

      expect(topic.custom_fields["solved_auto_close_topic_timer_id"].to_i).to eq(
        topic.public_topic_timer.id,
      )

      expect(topic.public_topic_timer.execute_at).to eq_time(Time.zone.now + 2.hours)

      expect(topic.public_topic_timer.based_on_last_post).to eq(true)
    end

    it "gives priority to category's solved_topics_auto_close_hours setting" do
      freeze_time
      custom_auto_close_category = Fabricate(:category)
      topic_2 = Fabricate(:topic, category: custom_auto_close_category)
      post_2 = Fabricate(:post, topic: topic_2)
      custom_auto_close_category.custom_fields["solved_topics_auto_close_hours"] = 4
      custom_auto_close_category.save_custom_fields

      post "/solution/accept.json", params: { id: post_2.id }

      expect(response.status).to eq(200)
      expect(post_2.reload.custom_fields["is_accepted_answer"]).to eq("true")

      topic_2.reload

      expect(topic_2.public_topic_timer.status_type).to eq(TopicTimer.types[:silent_close])

      expect(topic_2.custom_fields["solved_auto_close_topic_timer_id"].to_i).to eq(
        topic_2.public_topic_timer.id,
      )

      expect(topic_2.public_topic_timer.execute_at).to eq_time(Time.zone.now + 4.hours)

      expect(topic_2.public_topic_timer.based_on_last_post).to eq(true)
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

    it "removes the solution when the post is deleted" do
      reply = Fabricate(:post, post_number: 2, topic: topic)

      post "/solution/accept.json", params: { id: reply.id }
      expect(response.status).to eq(200)

      reply.reload
      expect(reply.custom_fields["is_accepted_answer"]).to eq("true")
      expect(reply.topic.custom_fields["accepted_answer_post_id"].to_i).to eq(reply.id)

      PostDestroyer.new(Discourse.system_user, reply).destroy

      reply.reload
      expect(reply.custom_fields["is_accepted_answer"]).to eq(nil)
      expect(reply.topic.custom_fields["accepted_answer_post_id"]).to eq(nil)
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
