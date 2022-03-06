import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import { test } from "qunit";
import { click, fillIn, visit } from "@ember/test-helpers";

acceptance("Discourse Solved Plugin", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const postStreamWithAcceptedAnswerExcerpt = (excerpt) => {
      return {
        post_stream: {
          posts: [
            {
              id: 21,
              name: null,
              username: "kzh",
              avatar_template:
                "/letter_avatar_proxy/v2/letter/k/ac91a4/{size}.png",
              created_at: "2017-08-08T20:11:32.542Z",
              cooked: "<p>How do I declare a variable in ruby?</p>",
              post_number: 1,
              post_type: 1,
              updated_at: "2017-08-08T21:03:30.521Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              avg_time: null,
              incoming_link_count: 0,
              reads: 1,
              score: 0,
              yours: true,
              topic_id: 23,
              topic_slug: "test-solved",
              display_username: null,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_bg_color: null,
              primary_group_flair_color: null,
              version: 2,
              can_edit: true,
              can_delete: false,
              can_recover: null,
              can_wiki: true,
              read: true,
              user_title: null,
              actions_summary: [
                { id: 3, can_act: true },
                { id: 4, can_act: true },
                { id: 5, hidden: true, can_act: true },
                { id: 7, can_act: true },
                { id: 8, can_act: true },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 1,
              hidden: false,
              hidden_reason_id: null,
              trust_level: 4,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              can_accept_answer: false,
              can_unaccept_answer: false,
              accepted_answer: false,
            },
            {
              id: 22,
              name: null,
              username: "kzh",
              avatar_template:
                "/letter_avatar_proxy/v2/letter/k/ac91a4/{size}.png",
              created_at: "2017-08-08T20:12:04.657Z",
              cooked:
                "<p>this is a long answer that potentially solves the question</p>",
              post_number: 2,
              post_type: 1,
              updated_at: "2017-08-08T21:20:24.417Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              avg_time: null,
              incoming_link_count: 0,
              reads: 1,
              score: 0,
              yours: true,
              topic_id: 23,
              topic_slug: "test-solved",
              display_username: null,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_bg_color: null,
              primary_group_flair_color: null,
              version: 2,
              can_edit: true,
              can_delete: true,
              can_recover: null,
              can_wiki: true,
              read: true,
              user_title: null,
              actions_summary: [
                { id: 3, can_act: true },
                { id: 4, can_act: true },
                { id: 5, hidden: true, can_act: true },
                { id: 7, can_act: true },
                { id: 8, can_act: true },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 1,
              hidden: false,
              hidden_reason_id: null,
              trust_level: 4,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              can_accept_answer: false,
              can_unaccept_answer: true,
              accepted_answer: true,
            },
          ],
          stream: [21, 22],
        },
        timeline_lookup: [[1, 0]],
        id: 23,
        title: "Test solved",
        fancy_title: "Test solved",
        posts_count: 2,
        created_at: "2017-08-08T20:11:32.098Z",
        views: 6,
        reply_count: 0,
        participant_count: 1,
        like_count: 0,
        last_posted_at: "2017-08-08T20:12:04.657Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "regular",
        slug: "test-solved",
        category_id: 1,
        word_count: 18,
        deleted_at: null,
        pending_posts_count: 0,
        user_id: 1,
        pm_with_non_human_user: false,
        draft: null,
        draft_key: "topic_23",
        draft_sequence: 6,
        posted: true,
        unpinned: null,
        pinned_globally: false,
        pinned: false,
        pinned_at: null,
        pinned_until: null,
        details: {
          created_by: {
            id: 1,
            username: "kzh",
            avatar_template:
              "/letter_avatar_proxy/v2/letter/k/ac91a4/{size}.png",
          },
          last_poster: {
            id: 1,
            username: "kzh",
            avatar_template:
              "/letter_avatar_proxy/v2/letter/k/ac91a4/{size}.png",
          },
          participants: [
            {
              id: 1,
              username: "kzh",
              avatar_template:
                "/letter_avatar_proxy/v2/letter/k/ac91a4/{size}.png",
              post_count: 2,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_color: null,
              primary_group_flair_bg_color: null,
            },
          ],
          notification_level: 3,
          notifications_reason_id: 1,
          can_move_posts: true,
          can_edit: true,
          can_delete: true,
          can_remove_allowed_users: true,
          can_invite_to: true,
          can_invite_via_email: true,
          can_create_post: true,
          can_reply_as_new_topic: true,
          can_flag_topic: true,
        },
        highest_post_number: 2,
        last_read_post_number: 2,
        last_read_post_id: 22,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          { id: 4, count: 0, hidden: false, can_act: true },
          { id: 7, count: 0, hidden: false, can_act: true },
          { id: 8, count: 0, hidden: false, can_act: true },
        ],
        chunk_size: 20,
        bookmarked: false,
        tags: [],
        featured_link: null,
        topic_timer: null,
        message_bus_last_id: 0,
        accepted_answer: { post_number: 2, username: "kzh", excerpt },
      };
    };

    server.get("/t/11.json", () => {
      return helper.response(
        postStreamWithAcceptedAnswerExcerpt("this is an excerpt")
      );
    });

    server.get("/t/12.json", () => {
      return helper.response(postStreamWithAcceptedAnswerExcerpt(null));
    });

    server.get("/search", () => {
      const fixtures = Object.assign({}, fixturesByUrl["/search.json"]);
      fixtures.topics[0].has_accepted_answer = true;
      return helper.response(fixtures);
    });
  });

  test("A topic with an accepted answer shows an excerpt of the answer, if provided", async function (assert) {
    await visit("/t/with-excerpt/11");

    assert.ok(
      queryAll('.quote blockquote:contains("this is an excerpt")').length === 1
    );

    await visit("/t/without-excerpt/12");

    assert.notOk(queryAll(".quote blockquote").length === 1);
    assert.ok(queryAll(".quote .title.title-only").length === 1);
  });

  test("Full page search displays solved status", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    assert.ok(queryAll(".fps-topic").length === 1, "has one post");

    assert.ok(queryAll(".topic-status .solved").length, "shows the right icon");
  });
});
