# frozen_string_literal: true

module DiscourseSolved
  class PluginInitializer
    attr_reader :plugin

    def initialize(plugin)
      @plugin = plugin
    end

    def apply_plugin_api
      # this method should be overridden by subclasses
      raise NotImplementedError
    end
  end

  class AssignsReminderForTopicsQuery < PluginInitializer
    def apply_plugin_api
      plugin.register_modifier(:assigns_reminder_assigned_topics_query) do |query|
        next query if !SiteSetting.ignore_solved_topics_in_assigned_reminder
        query.where.not(id: DiscourseSolved::Solution.pluck(:topic_id))
      end
    end
  end
end
