# frozen_string_literal: true

class EnsuresUniqueAcceptedAnswerPostId < ActiveRecord::Migration[6.0]
  def change
    execute <<~SQL
      DELETE FROM topic_custom_fields f
      WHERE name = 'accepted_answer_post_id' AND id > (
        SELECT MIN(f2.id) FROM topic_custom_fields f2
          WHERE f2.topic_id = f.topic_id AND f2.name = f.name
      )
    SQL

    add_index :topic_custom_fields,
      :topic_id,
      name: :idx_topic_custom_fields_accepted_answer,
      unique: true,
      where: "name = 'accepted_answer_post_id'"
  end
end
