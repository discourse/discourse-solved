require 'rails_helper'

RSpec.describe TopicsController do
  let(:p1) { Fabricate(:post, like_count: 1) }
  let(:topic) { p1.topic }
  let(:p2) { Fabricate(:post, like_count: 2, topic: topic, user: Fabricate(:user)) }

  before do
    SiteSetting.allow_solved_on_all_topics = true
  end

  it 'should include correct schema information in header' do
    p2.custom_fields["is_accepted_answer"] = true
    p2.save_custom_fields

    topic.custom_fields["accepted_answer_post_id"] = p2.id
    topic.save_custom_fields

    get "/t/#{topic.slug}/#{topic.id}"

    expect(response.body).to include('<script type="application/ld+json">{"@context":"http://schema.org","@type":"QAPage","name":"%{title}","mainEntity":{"@type":"Question","name":"%{title}","text":"%{question_text}","upvoteCount":%{question_likes},"answerCount":%{reply_count},"dateCreated":"%{created_at}","author":{"@type":"Person","name":"%{username1}"},"acceptedAnswer":{"@type":"Answer","text":"%{answer_text}","upvoteCount":%{answer_likes},"dateCreated":"%{answered_at}","url":"%{answer_url}","author":{"@type":"Person","name":"%{username2}"}}}}</script>' % {
      title: topic.title,
      question_text: p1.excerpt,
      question_likes: p1.like_count,
      reply_count: topic.reply_count,
      created_at: topic.created_at.as_json,
      username1: topic.user&.name,
      answer_text: p2.excerpt,
      answer_likes: p2.like_count,
      answered_at: p2.created_at.as_json,
      answer_url: p2.full_url,
      username2: p2.user&.username
    })
  end
end
