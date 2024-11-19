import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n from "I18n";

const QUERY_PARAM_VALUES = {
  solved: "yes",
  unsolved: "no",
  all: null,
};

const UX_VALUES = {
  yes: "solved",
  no: "unsolved",
};

export default class SolvedStatusFilter extends Component {
  static shouldRender(args, context, owner) {
    const router = owner.lookup("service:router");

    if (
      !context.siteSettings.show_filter_by_solved_status ||
      router.currentRouteName === "discovery.categories" ||
      args.editingCategory
    ) {
      return false;
    } else if (
      context.siteSettings.allow_solved_on_all_topics ||
      router.currentRouteName === "tag.show"
    ) {
      return true;
    } else {
      return args.currentCategory?.enable_accepted_answers;
    }
  }

  @service router;
  @service siteSettings;

  get statuses() {
    return ["all", "solved", "unsolved"].map((status) => {
      return {
        name: I18n.t(`solved.topic_status_filter.${status}`),
        value: status,
      };
    });
  }

  get status() {
    const queryParamValue = this.router.currentRoute.queryParams?.solved;
    return UX_VALUES[queryParamValue] || "all";
  }

  @action
  changeStatus(newStatus) {
    this.router.transitionTo({
      queryParams: { solved: QUERY_PARAM_VALUES[newStatus] },
    });
  }
}
