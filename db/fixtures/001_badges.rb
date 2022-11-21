# frozen_string_literal: true

return unless badge_grouping = BadgeGrouping.find_by(name: "Community")

helpdesk_query = <<-EOS
SELECT p.user_id, p.id post_id, p.updated_at granted_at
FROM badge_posts p
WHERE p.post_number > 1 AND
    p.id IN (
      SELECT post_id FROM (
       SELECT pc.post_id, row_number()
       OVER (PARTITION BY p1.user_id ORDER BY pc.created_at) as rnum
       FROM post_custom_fields pc
       JOIN badge_posts p1 ON p1.id = pc.post_id
       JOIN topics t1 ON p1.topic_id = t1.id
       WHERE name = 'is_accepted_answer' AND
                    p1.user_id <> t1.user_id AND
        (
          :backfill OR
           p1.user_id IN (
                   select user_id from posts where p1.id IN (:post_ids)
           )
       )
) X  WHERE rnum = 1)
EOS

Badge.seed(:name) do |badge|
  badge.name = I18n.t("badges.helpdesk.name")
  badge.icon = "check-square"
  badge.badge_type_id = 3
  badge.badge_grouping = badge_grouping
  badge.description = I18n.t("badges.helpdesk.description")
  badge.query = helpdesk_query
  badge.listable = true
  badge.target_posts = true
  badge.enabled = false
  badge.trigger = Badge::Trigger::PostRevision
  badge.auto_revoke = true
  badge.show_posts = true
  badge.system = false
end

tech_support_query = <<-SQL
  SELECT p.user_id, MAX(pcf.created_at) AS granted_at
  FROM post_custom_fields pcf
       JOIN badge_posts p ON pcf.post_id = p.id
       JOIN topics t ON p.topic_id = t.id
  WHERE pcf.name = 'is_accepted_answer'
    AND p.user_id <> t.user_id -- ignore topics solved by OP
    AND (:backfill OR p.id IN (:post_ids))
  GROUP BY p.user_id
  HAVING COUNT(*) >= 10
SQL

Badge.seed(:name) do |badge|
  badge.name = I18n.t("badges.tech_support.name")
  badge.icon = "check-square"
  badge.badge_type_id = 2
  badge.badge_grouping = badge_grouping
  badge.description = I18n.t("badges.tech_support.description")
  badge.query = tech_support_query
  badge.listable = true
  badge.allow_title = true
  badge.target_posts = false
  badge.enabled = false
  badge.trigger = Badge::Trigger::PostRevision
  badge.auto_revoke = true
  badge.show_posts = false
  badge.system = false
end
