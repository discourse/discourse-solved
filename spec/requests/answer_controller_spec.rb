# frozen_string_literal: true

require "rails_helper"

describe DiscourseSolved::AnswerController do
  fab!(:user)
  fab!(:staff_user) { Fabricate(:admin) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:p) { Fabricate(:post, topic: topic) }
  fab!(:solution_post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    category.save_custom_fields

    # Give permission to accept solutions
    user.update!(trust_level: 1)
  end

  describe "#accept" do
    # 确保当前用户是话题创建者，以便他们可以接受答案
    before { topic.update!(user_id: user.id) }

    context "with rate limiting enabled" do
      it "applies rate limits to regular users" do
        sign_in(user)

        # First request should succeed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Try to make too many requests in a short time
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429) # Rate limited status
      end

      it "does not apply rate limits to staff" do
        sign_in(staff_user)

        # Staff users bypass rate limiting by default
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Can make multiple requests without hitting rate limits
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)
      end
    end

    context "with plugin modifier" do
      it "allows plugins to bypass rate limiting via modifier" do
        sign_in(user)

        # Example of how plugins can customize rate limiting behavior
        DiscoursePluginRegistry.register_modifier(
          :solved_answers_controller_run_rate_limiter,
        ) do |_, _|
          false # Skip rate limiting completely
        end

        # First request should succeed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Second request should also succeed because rate limiting is bypassed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Clean up
        DiscoursePluginRegistry.unregister_modifier(:solved_answers_controller_run_rate_limiter)
      end
    end
  end

  describe "#unaccept" do
    before do
      # 让用户成为话题创建者，这样他就有权限接受/取消接受答案
      topic.update!(user_id: user.id)

      # Set up an accepted solution first
      sign_in(user)
      post "/solution/accept.json", params: { id: solution_post.id }
      expect(response.status).to eq(200)
      sign_out
    end

    it "applies rate limits to regular users" do
      sign_in(user)

      # Try to make too many requests in a short time
      RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

      post "/solution/unaccept.json", params: { id: solution_post.id }
      expect(response.status).to eq(429) # Rate limited status
    end
  end
end
