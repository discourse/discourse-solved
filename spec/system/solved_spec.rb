# frozen_string_literal: true

describe "Solved", type: :system do
  fab!(:admin)
  fab!(:solver) { Fabricate(:user) }
  fab!(:accepter) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:post, user: admin).topic }
  fab!(:solver_post) { Fabricate(:post, topic:, user: solver, cooked: "The answer is 42") }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.accept_all_solutions_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.show_who_marked_solved = true
  end

  %w[enabled disabled].each do |value|
    before { SiteSetting.glimmer_post_stream_mode = value }

    context "when glimmer_post_stream_mode=#{value}" do
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
  end

  it "shows the solved post in user activity at /my/activity/solved" do
    Fabricate(:solved_topic, topic:, answer_post: solver_post, accepter:)

    sign_in(solver)
    visit "/my/activity/solved"

    expect(page.find(".post-list")).to have_content(solver_post.cooked)
  end
end
