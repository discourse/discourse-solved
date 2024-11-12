import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class SolvedUnacceptAnswerButton extends Component {
  @service appEvents;

  @action
  unacceptAnswer() {
    unacceptAnswer(this.args.post, this.appEvents);
  }

  <template>
    <span class="extra-buttons">
      {{#if @post.can_unaccept_answer}}
        <DButton
          class="post-action-menu__solved-accepted accepted fade-out"
          ...attributes
          @action={{this.unacceptAnswer}}
          @icon="check-square"
          @label="solved.solution"
          @title="solved.unaccept_answer"
        />
      {{else}}
        <span
          class="accepted-text"
          title={{i18n "solved.accepted_description"}}
        >
          <span>{{dIcon "check"}}</span>
          <span class="accepted-label">
            {{i18n "solved.solution"}}
          </span>
        </span>
      {{/if}}
    </span>
  </template>
}

export function unacceptAnswer(post, appEvents) {
  // TODO (glimmer-post-menu): Remove this exported function and move the code into the button action after the widget code is removed
  unacceptPost(post);

  appEvents.trigger("discourse-solved:solution-toggled", post);

  post.get("topic.postStream.posts").forEach((p) => {
    p.set("topic_accepted_answer", false);
    appEvents.trigger("post-stream:refresh", { id: p.id });
  });
}

function unacceptPost(post) {
  if (!post.can_unaccept_answer) {
    return;
  }
  const topic = post.topic;

  post.setProperties({
    can_accept_answer: true,
    can_unaccept_answer: false,
    accepted_answer: false,
  });

  topic.set("accepted_answer", undefined);

  ajax("/solution/unaccept", {
    type: "POST",
    data: { id: post.id },
  }).catch(popupAjaxError);
}
