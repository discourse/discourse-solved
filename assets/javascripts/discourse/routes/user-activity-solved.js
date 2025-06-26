import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

class SolvedPostsStream extends EmberObject {
  @tracked content = [];
  @tracked loading = false;
  @tracked loaded = false;
  @tracked itemsLoaded = 0;
  @tracked canLoadMore = true;

  constructor(args) {
    super(args);
    this.username = args.username;
    this.siteCategories = args.siteCategories;
  }

  get noContent() {
    return this.loaded && this.content.length === 0;
  }

  findItems() {
    if (this.loading || !this.canLoadMore) {
      return Promise.resolve();
    }

    this.set("loading", true);

    const limit = 20;
    return ajax(
      `/solution/by_user.json?username=${this.username}&offset=${this.itemsLoaded}&limit=${limit}`
    )
      .then((result) => {
        const userSolvedPosts = result.user_solved_posts || [];

        if (userSolvedPosts.length === 0) {
          this.set("canLoadMore", false);
          return;
        }

        const posts = userSolvedPosts.map((p) => {
          const post = EmberObject.create(p);
          post.set("titleHtml", post.topic_title);
          post.set("postUrl", post.url);

          if (post.category_id && this.siteCategories) {
            post.set(
              "category",
              this.siteCategories.find((c) => c.id === post.category_id)
            );
          }
          return post;
        });

        // Add to existing content
        if (this.content.pushObjects) {
          this.content.pushObjects(posts);
        } else {
          this.content = this.content.concat(posts);
        }

        this.set("itemsLoaded", this.itemsLoaded + userSolvedPosts.length);

        if (userSolvedPosts.length < limit) {
          this.set("canLoadMore", false);
        }
      })
      .finally(() => {
        this.setProperties({
          loaded: true,
          loading: false,
        });
      });
  }
}

export default class UserActivitySolved extends DiscourseRoute {
  @service site;
  @service currentUser;

  model() {
    const user = this.modelFor("user");

    const stream = new SolvedPostsStream({
      username: user.username,
      siteCategories: this.site.categories,
    });

    return stream.findItems().then(() => {
      return {
        stream,
        emptyState: this.emptyState(),
      };
    });
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      emptyState: this.emptyState(),
    });
  }

  renderTemplate() {
    this.render("user-activity-solved");
  }

  emptyState() {
    const user = this.modelFor("user");

    let title, body;
    if (this.currentUser && user.id === this.currentUser.id) {
      title = i18n("solved.no_solved_topics_title");
      body = i18n("solved.no_solved_topics_body");
    } else {
      title = i18n("solved.no_solved_topics_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  }
}
