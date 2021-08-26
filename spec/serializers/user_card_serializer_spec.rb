# frozen_string_literal: true

require 'rails_helper'

describe UserCardSerializer do
  let(:user) { Fabricate(:user) }
  let(:serializer) { described_class.new(user, scope: Guardian.new, root: false) }
  let(:json) { serializer.as_json }

  it "accepted_answers serializes number of accepted answers" do
    post = Fabricate(:post, user: user)
    post.upsert_custom_fields(is_accepted_answer: 'true')
    expect(serializer.as_json[:accepted_answers]).to eq(1)

    post = Fabricate(:post, user: user)
    post.upsert_custom_fields(is_accepted_answer: 'true')
    expect(serializer.as_json[:accepted_answers]).to eq(2)
  end
end
