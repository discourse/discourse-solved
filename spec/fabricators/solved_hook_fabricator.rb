# frozen_string_literal: true

Fabricator(:solved_web_hook, from: :web_hook) do
  transient solved_hook: WebHookEventType.find_by(name: "accepted_solution"),
            unsolved_hook: WebHookEventType.find_by(name: "unaccepted_solution")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:solved_hook], transients[:unsolved_hook]]
  end
end
