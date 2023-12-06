# frozen_string_literal: true

require "rails_helper"

describe UserCardSerializer do
  let(:user) { Fabricate(:user) }
  let(:serializer) { described_class.new(user, scope: Guardian.basic_user, root: false) }
  let(:json) { serializer.as_json }

  it "accepted_answers serializes number of accepted answers" do
    post1 = Fabricate(:post, user: user)
    DiscourseSolved.accept_answer!(post1, Discourse.system_user)
    expect(serializer.as_json[:accepted_answers]).to eq(1)

    post2 = Fabricate(:post, user: user)
    DiscourseSolved.accept_answer!(post2, Discourse.system_user)
    expect(serializer.as_json[:accepted_answers]).to eq(2)

    DiscourseSolved.unaccept_answer!(post1)
    expect(serializer.as_json[:accepted_answers]).to eq(1)
  end
end
