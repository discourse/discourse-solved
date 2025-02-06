import { later } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";

const ONE_WEEK = 7 * 24 * 60 * 60 * 1000; // milliseconds
const MAX_DURATION_WITH_NO_ANSWER = ONE_WEEK;
const DISPLAY_DELAY = isTesting() ? 0 : 2000;

export default {
  shouldRender(args, component) {
    return !component.site.mobileView;
  },

  setupComponent(args, component) {
    component.set("show", false);
    component.setProperties({
      oneWeek: ONE_WEEK,
      show: false,
    });

    later(() => {
      if (
        !component.element ||
        component.isDestroying ||
        component.isDestroyed
      ) {
        return;
      }

      const topic = args.topic;
      const currentUser = component.currentUser;

      // show notice if:
      // - user can accept answer
      // - it does not have an accepted answer
      // - topic is old
      // - topic has at least one reply from another user that can be accepted
      if (
        !topic.accepted_answer &&
        currentUser &&
        topic.user_id === currentUser.id &&
        moment() - moment(topic.created_at) > MAX_DURATION_WITH_NO_ANSWER &&
        topic.postStream.posts.some(
          (post) => post.user_id !== currentUser.id && post.can_accept_answer
        )
      ) {
        component.set("show", true);
      }
    }, DISPLAY_DELAY);
  },
};
