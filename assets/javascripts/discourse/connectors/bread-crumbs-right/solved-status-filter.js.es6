import DiscourseUrl from "discourse/lib/url";

export default {
  shouldRender(args, component) {
    if (!component.siteSettings.show_filter_by_solved_status) {
      return false;
    } else if (component.siteSettings.allow_solved_on_all_topics) {
      return true;
    } else {
      const controller = Discourse.__container__.lookup(
        "controller:navigation/category"
      );

      return controller && controller.get("category.enable_accepted_answers");
    }
  },

  setupComponent(args, component) {
    const statuses = ["all", "solved", "unsolved"].map(status => {
      return {
        name: I18n.t(`solved.topic_status_filter.${status}`),
        value: status
      };
    });
    component.set("statuses", statuses);

    const queryStrings = window.location.search;
    if (queryStrings.match(/solved=yes/)) {
      component.set("status", "solved");
    } else if (queryStrings.match(/solved=no/)) {
      component.set("status", "unsolved");
    } else {
      component.set("status", "all");
    }
  },

  actions: {
    changeStatus(newStatus) {
      let location = window.location;
      let queryStrings = location.search;
      let params = queryStrings.startsWith("?")
        ? queryStrings.substr(1).split("&")
        : [];

      params = params.filter(param => {
        return !param.startsWith("solved=");
      });

      if (newStatus && newStatus !== "all") {
        newStatus = newStatus === "solved" ? "yes" : "no";
        params.push(`solved=${newStatus}`);
      }

      queryStrings = params.length > 0 ? `?${params.join("&")}` : "";
      DiscourseUrl.routeTo(
        `${location.pathname}${queryStrings}${location.hash}`
      );
    }
  }
};
