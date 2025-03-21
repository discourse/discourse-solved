import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | solved-post", function (hooks) {
  setupRenderingTest(hooks);

  test("renders solved post information", async function (assert) {
    this.siteSettings = {
      display_name_on_posts: true
    };

    const post = {
      post_number: 1,
      topic: {
        id: 123,
        url: "/t/topic/123",
        accepted_answer: {
          username: "solver",
          name: "Solver Person",
          post_number: 7,
          excerpt: "This is the solution",
          accepter_username: "accepter",
          accepter_name: "Accepter Person"
        }
      }
    };

    this.set("outletArgs", { post });

    await render(hbs`<SolvedPost @outletArgs={{this.outletArgs}} />`);

    assert.dom(".accepted-answer").exists("shows accepted answer section");
    assert.dom(".accepted-answer[data-post='7']").exists("has correct post number");
    assert.dom(".accepted-answer[data-topic='123']").exists("has correct topic id");
    assert.dom(".title .accepted-answer--solver").includesText("Solved by solver in post #7", "shows solver name");
    assert.dom(".title .accepted-answer--accepter").includesText("Marked as solved by accepter", "shows accepter name");
    assert.dom("blockquote").hasText("This is the solution", "shows excerpt");
  });

  test("handles missing excerpt", async function (assert) {
    const post = {
      post_number: 1,
      topic: {
        id: 123,
        accepted_answer: {
          username: "solver",
          post_number: 7,
          accepter_username: "accepter"
        }
      }
    };

    this.set("outletArgs", { post });

    await render(hbs`<SolvedPost @outletArgs={{this.outletArgs}} />`);

    assert.dom(".title").hasClass("title-only", "adds title-only class when no excerpt");
    assert.dom("blockquote").doesNotExist("doesn't show blockquote without excerpt");
  });

  test("uses username when display_name_on_posts is false", async function (assert) {
    this.siteSettings = {
      display_name_on_posts: false
    };

    const post = {
      post_number: 1,
      topic: {
        id: 123,
        accepted_answer: {
          username: "solver",
          name: "Solver Person",
          post_number: 7,
          accepter_username: "accepter",
          accepter_name: "Accepter Person"
        }
      }
    };

    this.set("outletArgs", { post });

    await render(hbs`<SolvedPost @outletArgs={{this.outletArgs}} />`);

    assert.dom(".title .accepted-answer--solver").includesText("solver", "shows username");
    assert.dom(".title .accepted-answer--accepter").includesText("accepter", "shows accepter username");
  });
});
