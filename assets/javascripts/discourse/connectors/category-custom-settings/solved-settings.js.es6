export default {
  actions: {
    onChangeSetting(value) {
      this.set(
        "category.custom_fields.enable_accepted_answers",
        value ? "true" : "false"
      );
    }
  }
};
