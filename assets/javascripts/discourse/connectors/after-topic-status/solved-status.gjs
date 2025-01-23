import Component from "@glimmer/component";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SolvedStatus extends Component {
  @service siteSettings;

  <template>
    {{~#if
      (or
        @outletArgs.topic.has_accepted_answer @outletArgs.topic.accepted_answer
      )
    ~}}
      <span
        title={{i18n "topic_statuses.solved.help"}}
        class="topic-status"
      >{{icon "far-square-check"}}</span>
    {{~else if @outletArgs.topic.can_have_answer~}}
      <span
        title={{i18n "solved.has_no_accepted_answer"}}
        class="topic-status"
      >{{icon "far-square"}}</span>
    {{~/if~}}
  </template>
}
