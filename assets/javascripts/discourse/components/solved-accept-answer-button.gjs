import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class SolvedAcceptAnswerButton extends Component {
  static collapsedByDefault(args) {
    return args.post.topic_accepted_answer;
  }

  @service appEvents;
  @service currentUser;

  get showLabel() {
    return this.currentUser?.id === this.args.post.topicCreatedById;
  }

  @action
  acceptAnswer() {
    acceptAnswer(this.args.post, this.appEvents);
  }

  <template>
    <DButton
      class="post-action-menu__solved-unaccepted unaccepted"
      ...attributes
      @action={{this.acceptAnswer}}
      @icon="far-check-square"
      @label={{if this.showLabel "solved.solution"}}
      @title="solved.accept_answer"
    />
  </template>
}

export function acceptAnswer(post, appEvents) {
  // TODO (glimmer-post-menu): Remove this exported function and move the code into the button action after the widget code is removed
  acceptPost(post);

  appEvents.trigger("discourse-solved:solution-toggled", post);

  post.get("topic.postStream.posts").forEach((p) => {
    p.set("topic_accepted_answer", true);
    appEvents.trigger("post-stream:refresh", { id: p.id });
  });
}

function acceptPost(post) {
  const topic = post.topic;

  clearAccepted(topic);

  post.setProperties({
    can_unaccept_answer: true,
    can_accept_answer: false,
    accepted_answer: true,
  });

  topic.set("accepted_answer", {
    username: post.username,
    name: post.name,
    post_number: post.post_number,
    excerpt: post.cooked,
  });

  ajax("/solution/accept", {
    type: "POST",
    data: { id: post.id },
  }).catch(popupAjaxError);
}

function clearAccepted(topic) {
  const posts = topic.get("postStream.posts");
  posts.forEach((post) => {
    if (post.get("post_number") > 1) {
      post.setProperties({
        accepted_answer: false,
        can_accept_answer: true,
        can_unaccept_answer: false,
        topic_accepted_answer: false,
      });
    }
  });
}
