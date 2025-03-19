# frozen_string_literal: true
#
class AddIndexForDiscourseSolvedTopics < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :discourse_solved_topics, :topic_id, unique: true, algorithm: :concurrently
    add_index :discourse_solved_topics, :answer_post_id, unique: true, algorithm: :concurrently
  end
end
