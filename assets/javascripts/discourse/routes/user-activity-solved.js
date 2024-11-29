import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import I18n from "I18n";

export default class UserActivitySolved extends UserActivityStreamRoute {
  userActionType = 15;
  noContentHelpKey = "solved.no_solutions";

  emptyState() {
    const user = this.modelFor("user");

    let title, body;
    if (this.isCurrentUser(user)) {
      title = I18n.t("solved.no_solved_topics_title");
      body = I18n.t("solved.no_solved_topics_body");
    } else {
      title = I18n.t("solved.no_solved_topics_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  }
}
