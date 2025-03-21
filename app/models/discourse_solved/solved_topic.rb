# frozen_string_literal: true

module DiscourseSolved
  class SolvedTopic < ActiveRecord::Base
    self.table_name = "discourse_solved_solved_topics"

    belongs_to :topic, class_name: "Topic"
    belongs_to :answer_post, class_name: "Post", foreign_key: "answer_post_id"
    belongs_to :accepter, class_name: "User", foreign_key: "accepter_user_id"
    belongs_to :topic_timer

    validates :topic_id, presence: true
    validates :answer_post_id, presence: true
  end
end
