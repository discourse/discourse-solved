# frozen_string_literal: true

require 'rails_helper'
require 'post_revisor'

describe PostRevisor do
  fab!(:category) { Fabricate(:category_with_definition) }

  fab!(:category_solved) do
    category = Fabricate(:category_with_definition)
    category.upsert_custom_fields("enable_accepted_answers" => "true")
    category
  end

  it "refreshes post stream when topic category changes to a solved category" do
    topic = Fabricate(:topic, category: Fabricate(:category_with_definition))
    post = Fabricate(:post, topic: topic)

    messages = MessageBus.track_publish("/topic/#{topic.id}") do
      described_class.new(post).revise!(Fabricate(:admin), { category_id: category.id })
    end

    expect(messages.first.data[:refresh_stream]).to eq(nil)

    messages = MessageBus.track_publish("/topic/#{topic.id}") do
      described_class.new(post).revise!(Fabricate(:admin), { category_id: category_solved.id })
    end

    expect(messages.first.data[:refresh_stream]).to eq(true)
  end
end
