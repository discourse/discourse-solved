import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import { iconHTML } from "discourse/lib/icon-library";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class SolvedAcceptedAnswer extends Component {
  @service siteSettings;
  @service store;

  get topic() {
    return this.args.post.topic;
  }

  get hasExcerpt() {
    return !!this.topic.accepted_answer.excerpt;
  }

  get htmlAccepter() {
    const username = this.topic.accepted_answer.accepter_username;
    const name = this.topic.accepted_answer.accepter_name;

    if (!this.siteSettings.show_who_marked_solved) {
      return;
    }

    const formattedUsername =
      this.siteSettings.display_name_on_posts && name
        ? name
        : formatUsername(username);

    return htmlSafe(
      i18n("solved.marked_solved_by", {
        username: formattedUsername,
        username_lower: username.toLowerCase(),
      })
    );
  }

  get htmlExcerpt() {
    return htmlSafe(this.topic.accepted_answer.excerpt);
  }

  get htmlSolvedBy() {
    const username = this.topic.accepted_answer.username;
    const name = this.topic.accepted_answer.name;
    const postNumber = this.topic.accepted_answer.post_number;

    if (!username || !postNumber) {
      return;
    }

    const displayedUser =
      this.siteSettings.display_name_on_posts && name
        ? name
        : formatUsername(username);

    const data = {
      icon: iconHTML("square-check", { class: "accepted" }),
      username_lower: username.toLowerCase(),
      username: displayedUser,
      post_path: `${this.topic.url}/${postNumber}`,
      post_number: postNumber,
      user_path: this.store.createRecord("user", { username }).path,
    };

    return htmlSafe(i18n("solved.accepted_html", data));
  }

  <template>
    <aside
      class="quote accepted-answer"
      data-post={{this.topic.accepted_answer.post_number}}
      data-topic={{this.topic.id}}
    >
      <div class={{concatClass "title" (unless this.hasExcerpt "title-only")}}>
        <div class="accepted-answer--solver-accepter">
          <div class="accepted-answer--solver">
            {{this.htmlSolvedBy}}
          </div>
          <div class="accepted-answer--accepter">
            {{this.htmlAccepter}}
          </div>
        </div>
        <div class="quote-controls"></div>
      </div>
      {{#if this.hasExcerpt}}
        <blockquote>
          {{this.htmlExcerpt}}
        </blockquote>
      {{/if}}
    </aside>
  </template>
}
