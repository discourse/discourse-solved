import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import AsyncContent from "discourse/components/async-content";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import PostCookedHtml from "discourse/components/post/cooked-html";
import UserLink from "discourse/components/user-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import escape from "discourse/lib/escape";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class SolvedAcceptedAnswer extends Component {
  @service siteSettings;
  @service store;

  @tracked expanded = false;

  get acceptedAnswer() {
    return this.topic.accepted_answer;
  }

  get quoteId() {
    return `accepted-answer-${this.topic.id}-${this.acceptedAnswer.post_number}`;
  }

  get topic() {
    return this.args.post.topic;
  }

  get hasExcerpt() {
    return !!this.acceptedAnswer.excerpt;
  }

  get htmlAccepter() {
    const username = this.acceptedAnswer.accepter_username;
    const name = this.acceptedAnswer.accepter_name;

    const formattedUsername =
      this.siteSettings.display_name_on_posts && name
        ? escape(name)
        : formatUsername(username);

    return htmlSafe(
      i18n("solved.marked_solved_by", {
        username: formattedUsername,
        username_lower: username.toLowerCase(),
      })
    );
  }

  get showMarkedBy() {
    return this.siteSettings.show_who_marked_solved;
  }

  get showSolvedBy() {
    return !(!this.acceptedAnswer.username || !this.acceptedAnswer.post_number);
  }

  get postNumber() {
    return i18n("solved.accepted_answer_post_number", {
      post_number: this.acceptedAnswer.post_number,
    });
  }

  get solverUsername() {
    return this.acceptedAnswer.username;
  }

  get accepterUsername() {
    return this.acceptedAnswer.accepter_username;
  }

  get solverDisplayName() {
    const username = this.acceptedAnswer.username;
    const name = this.acceptedAnswer.name;

    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  get accepterDisplayName() {
    const username = this.acceptedAnswer.accepter_username;
    const name = this.acceptedAnswer.accepter_name;

    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  get postPath() {
    const postNumber = this.acceptedAnswer.post_number;
    return `${this.topic.url}/${postNumber}`;
  }

  @action
  toggleExpandedPost() {
    if (!this.hasExcerpt) {
      return;
    }

    this.expanded = !this.expanded;
  }

  @action
  async loadExpandedAcceptedAnswer(postNumber) {
    const acceptedAnswer = await ajax(
      `/posts/by_number/${this.topic.id}/${postNumber}`
    );

    return this.store.createRecord("post", acceptedAnswer);
  }

  <template>
    <aside
      class="quote accepted-answer"
      data-post={{this.acceptedAnswer.post_number}}
      data-topic={{this.topic.id}}
      data-expanded={{this.expanded}}
    >
      {{! template-lint-disable no-invalid-interactive }}
      <div
        class={{concatClass
          "title"
          (unless this.hasExcerpt "title-only")
          (if this.hasExcerpt "quote__title--can-toggle-content")
        }}
        {{on "click" this.toggleExpandedPost}}
      >
        <div class="accepted-answer--solver-accepter">
          <div class="accepted-answer--solver">
            {{#if this.showSolvedBy}}
              {{icon "square-check" class="accepted"}}
              <InterpolatedTranslation
                @key="solved.accepted_answer_solver_info"
                as |Placeholder|
              >
                <Placeholder @name="user">
                  <UserLink
                    @username={{this.solverUsername}}
                  >{{this.solverDisplayName}}</UserLink>
                </Placeholder>
                <Placeholder @name="post">
                  <a href={{this.postPath}}>{{this.postNumber}}</a>
                </Placeholder>
              </InterpolatedTranslation>
              <br />
            {{/if}}

          </div>
          <div class="accepted-answer--accepter">
            {{#if this.showMarkedBy}}
              <InterpolatedTranslation
                @key="solved.marked_solved_by"
                as |Placeholder|
              >
                <Placeholder @name="user">
                  <UserLink
                    @username={{this.accepterUsername}}
                  >{{this.accepterDisplayName}}</UserLink>
                </Placeholder>
              </InterpolatedTranslation>
            {{/if}}
          </div>
        </div>
        {{#if this.hasExcerpt}}
          <div class="quote-controls">
            <button
              aria-controls={{this.quoteId}}
              aria-expanded={{this.expanded}}
              class="quote-toggle btn-flat"
              type="button"
            >
              {{icon
                (if this.expanded "chevron-up" "chevron-down")
                title="post.expand_collapse"
              }}
            </button>
          </div>
        {{/if}}
      </div>
      {{#if this.hasExcerpt}}
        <blockquote id={{this.quoteId}}>
          {{#if this.expanded}}
            <AsyncContent
              @asyncData={{this.loadExpandedAcceptedAnswer}}
              @context={{this.acceptedAnswer.post_number}}
            >
              <:content as |expandedAnswer|>
                <div class="expanded-quote" data-post-id={{expandedAnswer.id}}>
                  <PostCookedHtml
                    @post={{expandedAnswer}}
                    @streamElement={{false}}
                  />
                </div>
              </:content>
            </AsyncContent>
          {{else}}
            {{htmlSafe this.acceptedAnswer.excerpt}}
          {{/if}}
        </blockquote>
      {{/if}}
    </aside>
  </template>
}
