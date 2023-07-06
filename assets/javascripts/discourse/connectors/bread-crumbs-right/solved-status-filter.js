import I18n from "I18n";
import { getOwner } from "discourse-common/lib/get-owner";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

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
  static shouldRender(args, helper) {
    const router = getOwner(this).lookup("service:router");

    if (
      !helper.siteSettings.show_filter_by_solved_status ||
      router.currentRouteName === "discovery.categories"
    ) {
      return false;
    } else if (helper.siteSettings.allow_solved_on_all_topics) {
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
    const queryParamValue =
      this.router.currentRoute.attributes?.modelParams?.solved;
    return UX_VALUES[queryParamValue] || "all";
  }

  @action
  changeStatus(newStatus) {
    this.router.transitionTo({
      queryParams: { solved: QUERY_PARAM_VALUES[newStatus] },
    });
  }
}
