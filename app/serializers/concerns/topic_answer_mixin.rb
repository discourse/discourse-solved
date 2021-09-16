# frozen_string_literal: true

module TopicAnswerMixin
  def self.included(klass)
    klass.attributes :has_accepted_answer, :can_have_answer
  end

  def has_accepted_answer
    object.custom_fields["accepted_answer_post_id"] ? true : false
  end

  def include_has_accepted_answer?
    SiteSetting.solved_enabled
  end

  def can_have_answer
    return true if SiteSetting.allow_solved_on_all_topics
    return false if object.closed || object.archived
    scope.allow_accepted_answer?(object.category_id, object.tags.map(&:name))
  end

  def include_can_have_answer?
    SiteSetting.solved_enabled && SiteSetting.empty_box_on_unsolved
  end
end
