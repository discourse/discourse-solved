import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Discourse Solved Plugin | activity/solved | empty state", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = { user_actions: [] };

    server.get("/user_actions.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("When looking at own activity it renders the empty state panel", async function (assert) {
    await visit("/u/eviltrout/activity/solved");
    assert.ok(exists("div.empty-state"));
  });

  test("When looking at another user's activity it renders the 'No activity' message", async function (assert) {
    await visit("/u/charlie/activity/solved");
    assert.ok(exists("div.alert-info"));
  });
});
