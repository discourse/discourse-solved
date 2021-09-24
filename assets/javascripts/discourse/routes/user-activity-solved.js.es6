import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import I18n from "I18n";

export default UserActivityStreamRoute.extend({
  userActionType: 15,
  noContentHelpKey: "solved.no_solutions",

  emptyState() {
    return {
      title: I18n.t("solved.no_solved_topics_title"),
      body: I18n.t("solved.no_solved_topics_body")
    };
  }
});
