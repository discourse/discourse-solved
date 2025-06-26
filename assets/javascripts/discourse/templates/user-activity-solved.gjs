import RouteTemplate from "ember-route-template";
import UserStream from "discourse/components/user-stream";

export default RouteTemplate(
  <template>
    {{#if @controller.model.stream.noContent}}
      <div class="empty-state">
        <span class="empty-state-title">
          {{@controller.model.emptyState.title}}
        </span>
        <div class="empty-state-body">
          {{{@controller.model.emptyState.body}}}
        </div>
      </div>
    {{/if}}

    <UserStream @stream={{@controller.model.stream}} />
  </template>
);
