import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

acceptance("Discourse Solved Plugin", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/t/11.json", () => {
      return helper.response(
        postStreamWithAcceptedAnswerExcerpt("this is an excerpt")
      );
    });

    server.get("/t/12.json", () => {
      return helper.response(postStreamWithAcceptedAnswerExcerpt(null));
    });

    server.get("/search", () => {
      const fixtures = cloneJSON(fixturesByUrl["/search.json"]);
      fixtures.topics[0].has_accepted_answer = true;
      return helper.response(fixtures);
    });
  });

  test("A topic with an accepted answer shows an excerpt of the answer, if provided", async function (assert) {
    await visit("/t/with-excerpt/11");

    assert.strictEqual(
      queryAll('.quote blockquote:contains("this is an excerpt")').length,
      1
    );

    await visit("/t/without-excerpt/12");

    assert.notStrictEqual(queryAll(".quote blockquote").length, 1);
    assert.strictEqual(queryAll(".quote .title.title-only").length, 1);
  });

  test("Full page search displays solved status", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    assert.strictEqual(queryAll(".fps-topic").length, 1, "has one post");

    assert.ok(queryAll(".topic-status .solved").length, "shows the right icon");
  });
});
