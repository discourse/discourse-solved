import Category from "discourse/models/category";

export default {
  name: "extend-category-for-solved",

  before: "inject-discourse-objects",

  initialize() {
    Category.reopen({
      enable_accepted_answers: Ember.computed(
        "custom_fields.enable_accepted_answers",
        {
          get(fieldName) {
            if (this.custom_fields) {
              return Ember.get(this.custom_fields, fieldName) === "true";
            } else if (this.preloaded_custom_fields) {
              return (
                Ember.get(this.preloaded_custom_fields, fieldName) === "true"
              );
            } else {
              return false;
            }
          },
        }
      ),
    });
  },
};
