import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

acceptance(
  "Discourse Solved | Widget Post Menu |Accept and Unaccept",
  function (needs) {
    needs.user({
      admin: true,
    });

    needs.settings({
      glimmer_post_menu_mode: "disabled",
      solved_enabled: true,
      allow_solved_on_all_topics: true,
    });

    needs.pretender((server, helper) => {
      server.post("/solution/accept", () => helper.response({ success: "OK" }));
      server.post("/solution/unaccept", () =>
        helper.response({ success: "OK" })
      );

      server.get("/t/12.json", () => {
        return helper.response(postStreamWithAcceptedAnswerExcerpt(null));
      });
    });

    test("accepting and unaccepting a post works", async function (assert) {
      await visit("/t/without-excerpt/12");

      assert
        .dom("#post_2 .accepted")
        .exists("Unaccept button is visible")
        .hasText(I18n.t("solved.solution"), "Unaccept button has correct text");

      await click("#post_2 .accepted");

      assert.dom("#post_2 .unaccepted").exists("Accept button is visible");

      await click("#post_2 .unaccepted");

      assert.dom("#post_2 .accepted").exists("Unccept button is visible again");
    });
  }
);
