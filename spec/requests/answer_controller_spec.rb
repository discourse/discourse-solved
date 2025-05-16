# frozen_string_literal: true

require "rails_helper"

describe DiscourseSolved::AnswerController do
  fab!(:user)
  fab!(:high_trust_user) { Fabricate(:user, trust_level: 3) }
  fab!(:staff_user) { Fabricate(:admin) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:solution_post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    category.save_custom_fields

    # Make the topic's first post's user the topic creator
    # This ensures the guardian will allow the acceptance
    topic.user_id = user.id
    topic.save!

    # Make solution_post's user different from the topic creator
    solution_post.user_id = Fabricate(:user).id
    solution_post.save!

    # Give permission to accept solutions
    user.update!(trust_level: 1)
    high_trust_user.update!(trust_level: 3)
  end

  describe "#accept" do
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

    context "with bypass settings" do
      before do
        SiteSetting.solved_bypass_rate_limit = true
        SiteSetting.solved_min_trust_level_for_bypass = 3
      end

      it "applies rate limits to low trust users" do
        sign_in(user)

        # First request should succeed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Try to make too many requests in a short time
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429) # Rate limited status
      end

      it "does not apply rate limits to high trust users" do
        sign_in(high_trust_user)

        # First request should succeed without rate limiting
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Should be able to make another request without rate limiting
        RateLimiter.any_instance.expects(:performed!).never

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)
      end

      it "respects min trust level setting changes" do
        SiteSetting.solved_min_trust_level_for_bypass = 4

        sign_in(high_trust_user) # TL3 user

        # First request should succeed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Now rate limiting should apply since TL3 < TL4 requirement
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429) # Rate limited status
      end
    end

    context "with bypass disabled" do
      before do
        SiteSetting.solved_bypass_rate_limit = false
        SiteSetting.solved_min_trust_level_for_bypass = 3
      end

      it "applies rate limits to all non-staff users" do
        sign_in(high_trust_user) # TL3 user

        # First request should succeed
        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)

        # Rate limiting should apply despite high trust level because bypass is disabled
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        post "/solution/accept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429) # Rate limited status
      end
    end
  end

  describe "#unaccept" do
    before do
      # Set up an accepted solution first
      sign_in(user)
      post "/solution/accept.json", params: { id: solution_post.id }
      expect(response.status).to eq(200)
      sign_out
    end

    context "with bypass settings" do
      before do
        SiteSetting.solved_bypass_rate_limit = true
        SiteSetting.solved_min_trust_level_for_bypass = 3
      end

      it "applies rate limits to low trust users" do
        sign_in(user)

        # Try to make too many requests in a short time
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        post "/solution/unaccept.json", params: { id: solution_post.id }
        expect(response.status).to eq(429) # Rate limited status
      end

      it "does not apply rate limits to high trust users" do
        # Give topic ownership to high trust user so they can unaccept
        topic.user_id = high_trust_user.id
        topic.save!

        sign_in(high_trust_user)

        # Should be able to unaccept without rate limiting
        RateLimiter.any_instance.expects(:performed!).never

        post "/solution/unaccept.json", params: { id: solution_post.id }
        expect(response.status).to eq(200)
      end
    end
  end
end
