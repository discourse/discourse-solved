import discourseComputed from "discourse-common/utils/decorators";
import TopicListItem from "discourse/components/topic-list-item";

export default {
  name: "add-topic-list-class",
  initialize() {
    TopicListItem.reopen({
      @discourseComputed()
      unboundClassNames() {
        let classList = this._super(...arguments);
        if (this.topic.has_accepted_answer) {
          classList += " status-solved";
        }
        return classList;
      },
    });
  },
};
