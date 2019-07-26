import Category from "discourse/models/category";

export default {
  name: "extend-category-for-solved",

  before: "inject-discourse-objects",

  initialize() {
    Category.reopen({
      enable_accepted_answers: Ember.computed(
        "custom_fields.enable_accepted_answers",
        {
          get(enableField) {
            return enableField === "true";
          },
          set(value) {
            value = value ? "true" : "false";
            this.set("custom_fields.enable_accepted_answers", value);
            return value;
          }
        }
      )
    });
  }
};
