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

    # Make user the topic creator so they can accept answers
    topic.update!(user_id: user.id)
  end

  describe "#accept" do
    context "with default rate limiting" do
      it "applies rate limits to regular users" do
        sign_in(user)

        # First request should succeed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Second request should be rate limited
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429)
      end

      it "does not apply rate limits to staff" do
        sign_in(staff_user)

        # Staff can make multiple requests without hitting limits
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)
      end
    end

    context "with plugin modifier" do
     it "allows plugins to bypass rate limiting" do
       sign_in(user)
       # Store the block in a variable so we can reference it for unregistration
       block = ->(_, _) { false }
       # Register modifier with proper parameters - plugin instance (self) and name
       DiscoursePluginRegistry.register_modifier(
         self,
         :solved_answers_controller_run_rate_limiter,
         &block
       )
       post "/solution/accept.json", params: { id: solution_post.id }
       expect(response.status).to eq(200)
       post "/solution/accept.json", params: { id: solution_post.id }
       expect(response.status).to eq(200)
       # Unregister with the same plugin instance and block
       DiscoursePluginRegistry.unregister_modifier(
         self, # plugin_instance parameter
         :solved_answers_controller_run_rate_limiter, # name parameter
         &block # same block used for registration
       )
     end
   end
  end
  describe "#unaccept" do
    before do
      # Setup an accepted solution
      sign_in(user)
      post "/solution/accept.json", params: { id: solution_post.id }
      expect(response.status).to eq(200)
      sign_out
    end

    it "applies rate limits to regular users" do
      sign_in(user)

      # Should be rate limited
      RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))
      post "/solution/unaccept.json", params: { id: solution_post.id }
      expect(response.status).to eq(429)
    end
  end
end
