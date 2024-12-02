import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(
  "Discourse Solved Plugin | activity/solved | empty state",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/user_actions.json", () =>
        helper.response({ user_actions: [] })
      );
    });

    test("When looking at own activity", async function (assert) {
      await visit(`/u/eviltrout/activity/solved`);

      assert
        .dom("div.empty-state span.empty-state-title")
        .hasText(i18n("solved.no_solved_topics_title"));
      assert
        .dom("div.empty-state div.empty-state-body")
        .hasText(i18n("solved.no_solved_topics_body"));
    });

    test("When looking at another user's activity", async function (assert) {
      await visit(`/u/charlie/activity/solved`);

      assert.dom("div.empty-state span.empty-state-title").hasText(
        i18n("solved.no_solved_topics_title_others", {
          username: "charlie",
        })
      );
      assert.dom("div.empty-state div.empty-state-body").hasNoText();
    });
  }
);
