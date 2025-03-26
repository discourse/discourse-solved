import { computed } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { iconHTML, iconNode } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { formatUsername } from "discourse/lib/utilities";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import PostCooked from "discourse/widgets/post-cooked";
import { i18n } from "discourse-i18n";
import SolvedAcceptAnswerButton, {
  acceptAnswer,
} from "../components/solved-accept-answer-button";
import SolvedUnacceptAnswerButton, {
  unacceptAnswer,
} from "../components/solved-unaccept-answer-button";

function initializeWithApi(api) {
  customizePostMenu(api);

  api.includePostAttributes(
    "can_accept_answer",
    "can_unaccept_answer",
    "accepted_answer",
    "topic_accepted_answer"
  );

  if (api.addDiscoveryQueryParam) {
    api.addDiscoveryQueryParam("solved", { replace: true, refreshModel: true });
  }

  api.decorateWidget("post-contents:after-cooked", (dec) => {
    if (dec.attrs.post_number === 1) {
      const postModel = dec.getModel();
      if (postModel) {
        const topic = postModel.topic;
        if (topic.accepted_answer) {
          const hasExcerpt = !!topic.accepted_answer.excerpt;
          const excerpt = hasExcerpt
            ? ` <blockquote> ${topic.accepted_answer.excerpt} </blockquote> `
            : "";
          const solvedQuote = `
            <aside class='quote accepted-answer' data-post="${topic.get("accepted_answer").post_number}" data-topic="${topic.id}">
              <div class='title ${hasExcerpt ? "" : "title-only"}'>
                <div class="accepted-answer--solver-accepter">
                  <div class="accepted-answer--solver">
                    ${topic.solvedByHtml}
                  <\/div>
                  <div class="accepted-answer--accepter">
                    ${topic.accepterHtml}
                  <\/div>
                </div>
                <div class="quote-controls"><\/div>
              </div>
              ${excerpt}
            </aside>`;

          const cooked = new PostCooked({ cooked: solvedQuote }, dec);
          return dec.rawHtml(cooked.init());
        }
      }
    }
  });

  api.attachWidgetAction("post", "acceptAnswer", function () {
    acceptAnswer(this.model, this.appEvents, this.currentUser);
  });

  api.attachWidgetAction("post", "unacceptAnswer", function () {
    unacceptAnswer(this.model, this.appEvents);
  });
}

function customizePostMenu(api) {
  const transformerRegistered = api.registerValueTransformer(
    "post-menu-buttons",
    ({
      value: dag,
      context: {
        post,
        firstButtonKey,
        secondLastHiddenButtonKey,
        lastHiddenButtonKey,
      },
    }) => {
      let solvedButton;

      if (post.can_accept_answer) {
        solvedButton = SolvedAcceptAnswerButton;
      } else if (post.accepted_answer) {
        solvedButton = SolvedUnacceptAnswerButton;
      }

      solvedButton &&
        dag.add(
          "solved",
          solvedButton,
          post.topic_accepted_answer && !post.accepted_answer
            ? {
                before: lastHiddenButtonKey,
                after: secondLastHiddenButtonKey,
              }
            : {
                before: [
                  "assign", // button added by the assign plugin
                  firstButtonKey,
                ],
              }
        );
    }
  );

  const silencedKey =
    transformerRegistered && "discourse.post-menu-widget-overrides";

  withSilencedDeprecations(silencedKey, () => customizeWidgetPostMenu(api));
}

function customizeWidgetPostMenu(api) {
  const currentUser = api.getCurrentUser();

  api.addPostMenuButton("solved", (attrs) => {
    if (attrs.can_accept_answer) {
      const isOp = currentUser?.id === attrs.topicCreatedById;

      return {
        action: "acceptAnswer",
        icon: "far-square-check",
        className: "unaccepted",
        title: "solved.accept_answer",
        label: isOp ? "solved.solution" : null,
        position: attrs.topic_accepted_answer ? "second-last-hidden" : "first",
      };
    } else if (attrs.accepted_answer) {
      if (attrs.can_unaccept_answer) {
        return {
          action: "unacceptAnswer",
          icon: "square-check",
          title: "solved.unaccept_answer",
          className: "accepted fade-out",
          position: "first",
          label: "solved.solution",
        };
      } else {
        return {
          className: "hidden",
          disabled: "true",
          position: "first",
          beforeButton(h) {
            return h(
              "span.accepted-text",
              {
                title: i18n("solved.accepted_description"),
              },
              [
                h("span", iconNode("check")),
                h("span.accepted-label", i18n("solved.solution")),
              ]
            );
          },
        };
      }
    }
  });
}

export default {
  name: "extend-for-solved-button",
  initialize() {
    Topic.reopen({
      // keeping this here cause there is complex localization
      solvedByHtml: computed("accepted_answer", "id", function () {
        const username = this.get("accepted_answer.username");
        const name = this.get("accepted_answer.name");
        const postNumber = this.get("accepted_answer.post_number");

        if (!username || !postNumber) {
          return "";
        }

        const displayedUser =
          this.siteSettings.display_name_on_posts && name
            ? name
            : formatUsername(username);

        return i18n("solved.accepted_html", {
          icon: iconHTML("square-check", { class: "accepted" }),
          username_lower: username.toLowerCase(),
          username: displayedUser,
          post_path: `${this.url}/${postNumber}`,
          post_number: postNumber,
          user_path: User.create({ username }).path,
        });
      }),
      accepterHtml: computed("accepted_answer", function () {
        const username = this.get("accepted_answer.accepter_username");
        const name = this.get("accepted_answer.accepter_name");
        if (!this.siteSettings.show_who_marked_solved) {
          return "";
        }
        const formattedUsername =
          this.siteSettings.display_name_on_posts && name
            ? name
            : formatUsername(username);
        return i18n("solved.marked_solved_by", {
          username: formattedUsername,
          username_lower: username.toLowerCase(),
        });
      }),
    });

    withPluginApi("2.0.0", (api) => {
      withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
        let topicStatusIcons;
        try {
          topicStatusIcons =
            require("discourse/helpers/topic-status-icons").default;
        } catch {}

        topicStatusIcons?.addObject([
          "has_accepted_answer",
          "far-square-check",
          "solved",
        ]);

        api.modifyClass(
          "raw-view:topic-status",
          (Superclass) =>
            class extends Superclass {
              @discourseComputed(
                "topic.{has_accepted_answer,accepted_answer,can_have_answer}"
              )
              statuses() {
                const results = super.statuses;

                if (
                  this.topic.has_accepted_answer ||
                  this.topic.accepted_answer
                ) {
                  results.push({
                    openTag: "span",
                    closeTag: "span",
                    title: i18n("topic_statuses.solved.help"),
                    icon: "far-square-check",
                    key: "solved",
                  });
                } else if (this.topic.can_have_answer) {
                  results.push({
                    openTag: "span",
                    closeTag: "span",
                    title: i18n("solved.has_no_accepted_answer"),
                    icon: "far-square",
                  });
                }

                return results;
              }
            }
        );
      });
    });

    withPluginApi("1.34.0", initializeWithApi);

    withPluginApi("0.8.10", (api) => {
      api.replaceIcon(
        "notification.solved.accepted_notification",
        "square-check"
      );
    });

    withPluginApi("0.11.0", (api) => {
      api.addAdvancedSearchOptions({
        statusOptions: [
          {
            name: i18n("search.advanced.statuses.solved"),
            value: "solved",
          },
          {
            name: i18n("search.advanced.statuses.unsolved"),
            value: "unsolved",
          },
        ],
      });
    });

    withPluginApi("0.11.7", (api) => {
      api.addSearchSuggestion("status:solved");
      api.addSearchSuggestion("status:unsolved");
    });
  },
};
