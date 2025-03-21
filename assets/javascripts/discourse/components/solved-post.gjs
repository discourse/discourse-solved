import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { iconHTML } from "discourse/lib/icon-library";
import { formatUsername } from "discourse/lib/utilities";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SolvedPost extends Component {
  static shouldRender(args) {
    return args.post?.post_number === 1 && args.post?.topic?.accepted_answer;
  }

  @service siteSettings;

  get answerPostPath() {
    return `${this.args.outletArgs.post.topic.url}/${this.answerPostNumber}`;
  }

  get acceptedAnswer() {
    return this.args.outletArgs.post.topic.accepted_answer;
  }

  get answerPostNumber() {
    return this.acceptedAnswer?.post_number;
  }

  get topicId() {
    return this.args.outletArgs.post.topic.id;
  }

  get hasExcerpt() {
    return !!this.solvedExcerpt;
  }

  get solvedExcerpt() {
    return this.acceptedAnswer?.excerpt;
  }

  get username() {
    return this.acceptedAnswer?.username;
  }

  get displayedUser() {
    const { name, username } = this.acceptedAnswer || {};
    return this.siteSettings.display_name_on_posts && name
      ? name
      : formatUsername(username);
  }

  get title() {
    return i18n("solved.accepted_html", {
      icon: iconHTML("square-check", { class: "accepted" }),
      username_lower: this.username?.toLowerCase(),
      username: this.displayedUser,
      post_path: this.answerPostPath,
      post_number: this.answerPostNumber,
      user_path: User.create({ username: this.username }).path,
    });
  }

  get accepter() {
    const accepterUsername = this.acceptedAnswer?.accepter_username;
    const accepterName = this.acceptedAnswer?.accepter_name;
    const formattedUsername = this.siteSettings.display_name_on_posts && accepterName
      ? accepterName
      : formatUsername(accepterUsername);
    return i18n("solved.marked_solved_by", {
      username: formattedUsername,
      username_lower: accepterUsername.toLowerCase()
    });
  }

  <template>
    <div class="cooked">
      <aside class="quote accepted-answer"
             data-post={{this.answerPostNumber}}
             data-topic={{this.topicId}}>
        <div
          class={{concatClass "title" (unless this.hasExcerpt "title-only") }}
        >
          <div class="accepted-answer--solver">
            {{htmlSafe this.title}}
          </div>
          <div class="accepted-answer--accepter">
            {{htmlSafe this.accepter}}
          </div>
          <div class="quote-controls"></div>
        </div>
        {{#if this.hasExcerpt}}
          <blockquote>
            {{this.solvedExcerpt}}
          </blockquote>
        {{/if}}
      </aside>
    </div>
  </template>
}
