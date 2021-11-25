import { later } from "@ember/runloop";

// 7 days in milliseconds
const MAX_DURATION_WITH_NO_ANSWER = 7 * 24 * 60 * 60 * 1000;

export default {
  setupComponent(args, component) {
    this.set("show", false);

    later(() => {
      const topic = args.topic;
      const currentUser = component.currentUser;

      // show notice if:
      // - user can accept answer
      // - it does not have an accepted answer
      // - topic is old
      // - topic has at least one reply from another user
      if (
        !topic.accepted_answer &&
        topic.user_id === currentUser.id &&
        moment() - moment(topic.created_at) > MAX_DURATION_WITH_NO_ANSWER &&
        topic.postStream.posts.some((post) => post.user_id !== currentUser.id)
      ) {
        this.set("show", true);
      }
    }, 2000);
  },
};
