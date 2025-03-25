# frozen_string_literal: true
#
class CopyRemainingSolvedTopicCustomFieldToDiscourseSolvedSolvedTopics < ActiveRecord::Migration[
  7.2
]
  disable_ddl_transaction!

  BATCH_SIZE = 5000

  def up
    max_id = DB.query_single("SELECT MAX(id) FROM topic_custom_fields").first
    return unless max_id

    last_id = 0
    while last_id < max_id
      DB.exec(<<~SQL, last_id: last_id, batch_size: BATCH_SIZE)
        INSERT INTO discourse_solved_solved_topics (
          topic_id,
          answer_post_id,
          topic_timer_id,
          accepter_user_id,
          created_at,
          updated_at
        )
        SELECT DISTINCT ON (tc.topic_id)
          tc.topic_id,
          CAST(tc.value AS INTEGER),
          CAST(tc2.value AS INTEGER),
          COALESCE(ua.acting_user_id, -1),
          tc.created_at,
          tc.updated_at
        FROM topic_custom_fields tc
        LEFT JOIN topic_custom_fields tc2
          ON tc2.topic_id = tc.topic_id
          AND tc2.name = 'solved_auto_close_topic_timer_id'
        LEFT JOIN user_actions ua
          ON ua.target_topic_id = tc.topic_id
          AND ua.action_type = 15
        WHERE tc.name = 'accepted_answer_post_id'
          AND tc.id > :last_id
          AND tc.id <= :last_id + :batch_size
        ON CONFLICT (topic_id) DO NOTHING
      SQL

      last_id += BATCH_SIZE
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
