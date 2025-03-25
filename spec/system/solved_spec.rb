# frozen_string_literal: true

describe "About page", type: :system do
  fab!(:admin)
  fab!(:solver) { Fabricate(:user) }
  fab!(:accepter) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:post, user: admin).topic }
  fab!(:post1) { Fabricate(:post, topic:, user: solver, cooked: "The answer is 42") }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.accept_all_solutions_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  it "accepts post as solution and shows in OP" do
    sign_in(accepter)

    topic_page.visit_topic(topic, post_number: 2)

    expect(topic_page).to have_css(".post-action-menu__solved-unaccepted")

    find(".post-action-menu__solved-unaccepted").click

    expect(topic_page).to have_css(".post-action-menu__solved-accepted")
    expect(topic_page.find(".title .accepted-answer--solver")).to have_content(
      "Solved by #{solver.username}",
    )
    expect(topic_page.find(".title .accepted-answer--accepter")).to have_content(
      "Marked as solved by #{accepter.username}",
    )
    expect(topic_page.find("blockquote")).to have_content("The answer is 42")
  end
end
