import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";

acceptance(
  "Discourse Solved Plugin | activity/solved | empty state",
  function (needs) {
    const currentUser = "eviltrout";
    const anotherUser = "charlie";
    needs.user();

    needs.pretender((server, helper) => {
      const emptyResponse = { user_actions: [] };

      server.get("/user_actions.json", () => {
        return helper.response(emptyResponse);
      });
    });

    test("When looking at own activity", async function (assert) {
      await visit(`/u/${currentUser}/activity/solved`);

      assert.equal(
        query("div.empty-state span.empty-state-title").innerText,
        I18n.t("solved.no_solved_topics_title")
      );
      assert.equal(
        query("div.empty-state div.empty-state-body").innerText,
        I18n.t("solved.no_solved_topics_body")
      );
    });

    test("When looking at another user's activity", async function (assert) {
      await visit(`/u/${anotherUser}/activity/solved`);

      assert.equal(
        query("div.empty-state span.empty-state-title").innerText,
        I18n.t("solved.no_solved_topics_title_others", {
          username: anotherUser,
        })
      );
      assert.equal(query("div.empty-state div.empty-state-body").innerText, "");
    });
  }
);
