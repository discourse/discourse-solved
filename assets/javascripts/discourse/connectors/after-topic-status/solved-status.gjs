import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SolvedStatus extends Component {
  @service siteSettings;

  <template>
    {{~#if @topic.has_accepted_answer~}}
      <span
        title={{i18n "topic_statuses.solved.help"}}
        class="topic-status"
      >{{icon "far-square-check"}}</span>
    {{~else if
      (and
        @topic.can_have_answer
        this.siteSettings.solved_enabled
        this.siteSettings.empty_box_on_unsolved
      )
    ~}}
      <span
        title={{i18n "solved.has_no_accepted_answer"}}
        class="topic-status"
      >{{icon "far-square"}}</span>
    {{~/if~}}
  </template>
}
