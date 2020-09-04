import UserActivityStreamRoute from "discourse/routes/user-activity-stream";

export default UserActivityStreamRoute.extend({
  userActionType: 15,
  noContentHelpKey: "solved.no_solutions",
});
