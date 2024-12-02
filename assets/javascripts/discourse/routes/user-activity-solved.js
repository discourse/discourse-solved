import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { i18n } from "discourse-i18n";

export default class UserActivitySolved extends UserActivityStreamRoute {
  userActionType = 15;
  noContentHelpKey = "solved.no_solutions";

  emptyState() {
    const user = this.modelFor("user");

    let title, body;
    if (this.isCurrentUser(user)) {
      title = i18n("solved.no_solved_topics_title");
      body = i18n("solved.no_solved_topics_body");
    } else {
      title = i18n("solved.no_solved_topics_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  }
}
