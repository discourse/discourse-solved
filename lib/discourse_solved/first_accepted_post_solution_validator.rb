# frozen_string_literal: true

module DiscourseSolved
  class FirstAcceptedPostSolutionValidator
    def self.check(post, trust_level:)
      return false if post.archetype != Archetype.default
      return false if !post&.user&.human?
      return true if trust_level == "any"

      return false if TrustLevel.compare(post&.user&.trust_level, trust_level.to_i)

      if !UserAction.where(user_id: post&.user_id, action_type: UserAction::SOLVED).exists?
        return true
      end

      false
    end
  end
end
