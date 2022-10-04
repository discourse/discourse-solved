# frozen_string_literal: true

require 'rails_helper'

describe FirstAcceptedPostSolutionValidator do
  fab!(:user_tl1) { Fabricate(:user, trust_level: TrustLevel[1]) }

  context 'when user is under max trust level' do
    context 'with no post accepted yet' do
      it 'validates the post' do
        post_1 = create_post(user: user_tl1)
        expect(described_class.check(post_1, trust_level: TrustLevel[2])).to eq(true)
      end
    end

    context 'with already had accepted posts' do
      before do
        accepted_post = create_post(user: user_tl1)
        DiscourseSolved.accept_answer!(accepted_post, Discourse.system_user)
      end

      it 'doesn’t validate the post' do
        post_1 = create_post(user: user_tl1)
        expect(described_class.check(post_1, trust_level: TrustLevel[2])).to eq(false)
      end
    end
  end

  context 'when a user is above or equal max trust level' do
    context 'with no post accepted yet' do
      it 'doesn’t validate the post' do
        post_1 = create_post(user: user_tl1)
        expect(described_class.check(post_1, trust_level: TrustLevel[1])).to eq(false)
      end
    end

    context 'when a post is already accepted' do
      before do
        accepted_post = create_post(user: user_tl1)
        DiscourseSolved.accept_answer!(accepted_post, Discourse.system_user)
      end

      it 'doesn’t validate the post' do
        post_1 = create_post(user: user_tl1)
        expect(described_class.check(post_1, trust_level: TrustLevel[1])).to eq(false)
      end
    end
  end

  context 'when using any trust level' do
    it 'validates the post' do
      post_1 = create_post(user: user_tl1)
      expect(described_class.check(post_1, trust_level: 'any')).to eq(true)
    end
  end

  context 'when user is system' do
    it 'doesn’t validate the post' do
      post_1 = create_post(user: Discourse.system_user)
      expect(described_class.check(post_1, trust_level: 'any')).to eq(false)
    end
  end

  context 'when post is a PM' do
    it 'doesn’t validate the post' do
      Group.refresh_automatic_groups!
      post_1 = create_post(user: user_tl1, target_usernames: [user_tl1.username], archetype: Archetype.private_message)
      expect(described_class.check(post_1, trust_level: 'any')).to eq(false)
    end
  end
end
