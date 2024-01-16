# frozen_string_literal: true

module DiscourseSolved
  module GuardianExtensions
    def allow_accepted_answers?(category_id, tag_names = [])
      return true if SiteSetting.allow_solved_on_all_topics

      if SiteSetting.enable_solved_tags.present? && tag_names.present?
        allowed_tags = SiteSetting.enable_solved_tags.split("|")
        is_allowed = (tag_names & allowed_tags).present?

        return true if is_allowed
      end

      return false if category_id.blank?
      if !::DiscourseSolved::AcceptedAnswerCache.allowed
        ::DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
      end
      ::DiscourseSolved::AcceptedAnswerCache.allowed.include?(category_id)
    end

    def can_accept_answer?(topic, post)
      return false if !authenticated?
      return false if !topic || !post || post.whisper?
      return false if !allow_accepted_answers?(topic.category_id, topic.tags.map(&:name))

      return true if is_staff?
      return true if current_user.trust_level >= SiteSetting.accept_all_solutions_trust_level
      return true if can_perform_action_available_to_group_moderators?(topic)

      topic.user_id == current_user.id && !topic.closed && SiteSetting.accept_solutions_topic_author
    end
  end
end
