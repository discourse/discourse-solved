require 'rails_helper'

describe TopicAnswerMixin do
  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, topic: topic) }
  let(:guardian) { Guardian.new }

  before do
    topic.custom_fields["accepted_answer_post_id"] = post.id
    topic.save_custom_fields
  end

  it "should have true for `has_accepted_answer` field in each serializer" do
    [
      TopicListItemSerializer,
      SearchTopicListItemSerializer,
      SuggestedTopicSerializer,
      UserSummarySerializer::TopicSerializer
    ].each do |serializer|
      json = serializer.new(topic, scope: guardian, root: false).as_json
      expect(json[:has_accepted_answer]).to be_truthy
    end
  end
end
