# frozen_string_literal: true

module DiscourseSolved
  class RegisterFilters
    def self.register(plugin)
      solved_callback = ->(scope) do
        sql = <<~SQL
      topics.id IN (
        SELECT topic_id
          FROM topic_custom_fields
         WHERE name = '#{::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD}'
           AND value IS NOT NULL
      )
    SQL

        scope.where(sql).where("topics.archetype <> ?", Archetype.private_message)
      end
      unsolved_callback = ->(scope) do
        scope = scope.where <<~SQL
          topics.id NOT IN (
            SELECT topic_id
              FROM topic_custom_fields
             WHERE name = '#{::DiscourseSolved::ACCEPTED_ANSWER_POST_ID_CUSTOM_FIELD}'
               AND value IS NOT NULL
          )
        SQL

        if !SiteSetting.allow_solved_on_all_topics
          tag_ids = Tag.where(name: SiteSetting.enable_solved_tags.split("|")).pluck(:id)

          scope = scope.where <<~SQL, tag_ids
        topics.id IN (
          SELECT t.id
            FROM topics t
            JOIN category_custom_fields cc
              ON t.category_id = cc.category_id
             AND cc.name = '#{::DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD}'
             AND cc.value = 'true'
        )
        OR
        topics.id IN (
          SELECT topic_id
            FROM topic_tags
           WHERE tag_id IN (?)
        )
      SQL
        end

        scope.where("topics.archetype <> ?", Archetype.private_message)
      end

      plugin.register_custom_filter_by_status("solved", &solved_callback)
      plugin.register_custom_filter_by_status("unsolved", &unsolved_callback)

      plugin.register_search_advanced_filter(/status:solved/, &solved_callback)
      plugin.register_search_advanced_filter(/status:unsolved/, &unsolved_callback)

      TopicQuery.add_custom_filter(:solved) do |results, topic_query|
        if topic_query.options[:solved] == "yes"
          solved_callback.call(results)
        elsif topic_query.options[:solved] == "no"
          unsolved_callback.call(results)
        else
          results
        end
      end
    end
  end
end
