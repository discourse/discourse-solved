import TopicListItem from "discourse/components/topic-list-item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";

export default {
  name: "add-topic-list-class",

  initialize() {
    withPluginApi("1.39.0", (api) => {
      // TODO: cvx - remove after the glimmer topic list transition
      withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
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
      });

      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value, context }) => {
          if (context.topic.get("has_accepted_answer")) {
            value.push("status-solved");
          }
          return value;
        }
      );
    });
  },
};
