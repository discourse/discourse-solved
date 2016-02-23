import PostView from 'discourse/views/post';
import PostMenuComponent from 'discourse/components/post-menu';
import { Button } from 'discourse/components/post-menu';
import Topic from 'discourse/models/topic';
import User from 'discourse/models/user';
import TopicStatus from 'discourse/views/topic-status';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { withPluginApi } from 'discourse/lib/plugin-api';

function clearAccepted(topic) {
  const posts = topic.get('postStream.posts');
  posts.forEach(post => {
    if (post.get('post_number') > 1 ) {
      post.set('accepted_answer',false);
      post.set('can_accept_answer',true);
      post.set('can_unaccept_answer',false);
    }
  });
}

function unacceptPost(post) {
  if (!post.get('can_unaccept_answer')) { return; }
  const topic = post.topic;

  post.setProperties({
    can_accept_answer: true,
    can_unaccept_answer: false,
    accepted_answer: false
  });
  topic.set('accepted_answer', undefined);

  Discourse.ajax("/solution/unaccept", {
    type: 'POST',
    data: { id: post.get('id') }
  }).catch(popupAjaxError);
}

function acceptPost(post) {
  const topic = post.topic;

  clearAccepted(topic);

  post.setProperties({
    can_unaccept_answer: true,
    can_accept_answer: false,
    accepted_answer: true
  });

  topic.set('accepted_answer', {
    username: post.get('username'),
    post_number: post.get('post_number')
  });

  Discourse.ajax("/solution/accept", {
    type: 'POST',
    data: { id: post.get('.id') }
  }).catch(popupAjaxError);
}

// Code for older discourse installs for backwards compatibility
function oldPluginCode() {
  PostView.reopen({
    classNameBindings: ['post.accepted_answer:accepted-answer']
  });

  PostMenuComponent.registerButton(function(visibleButtons){
    var position = 0;

    var canAccept = this.get('post.can_accept_answer');
    var canUnaccept = this.get('post.can_unaccept_answer');
    var accepted = this.get('post.accepted_answer');
    var isOp = Discourse.User.currentProp("id") === this.get('post.topic.user_id');

    if  (!accepted && canAccept && !isOp) {
      // first hidden position
      if (this.get('collapsed')) { return; }
      position = visibleButtons.length - 2;
    }
    if (canAccept) {
      visibleButtons.splice(position,0,new Button('acceptAnswer', 'solved.accept_answer', 'check-square-o', {className: 'unaccepted'}));
    }
    if (canUnaccept || accepted) {
      var locale = canUnaccept ? 'solved.unaccept_answer' : 'solved.accepted_answer';
      visibleButtons.splice(position,0,new Button(
          'unacceptAnswer',
          locale,
          'check-square',
          {className: 'accepted fade-out', prefixHTML: '<span class="accepted-text">' + I18n.t('solved.solution') + '</span>'})
        );
    }

  });

  PostMenuComponent.reopen({
    acceptedChanged: function() {
      this.rerender();
    }.observes('post.accepted_answer'),

    clickUnacceptAnswer() {
      unacceptPost(this.get('post'));
    },

    clickAcceptAnswer() {
      acceptPost(this.get('post'));
    }
  });
}

function initializeWithApi(api) {
  const currentUser = api.getCurrentUser();

  api.includePostAttributes('can_accept_answer', 'can_unaccept_answer', 'accepted_answer');

  api.addPostMenuButton('solved', attrs => {
    const canAccept = attrs.can_accept_answer;
    const canUnaccept = attrs.can_unaccept_answer;
    const accepted = attrs.accepted_answer;
    const isOp = currentUser && currentUser.id === attrs.user_id;
    const position = (!accepted && canAccept && !isOp) ? 'second-last-hidden' : 'first';

    if (canAccept) {
      return {
        action: 'acceptAnswer',
        icon: 'check-square-o',
        className: 'unaccepted',
        title: 'solved.accept_answer',
        position
      };
    } else if (canUnaccept || accepted) {
      const title = canUnaccept ? 'solved.unaccept_answer' : 'solved.accepted_answer';
      return {
        action: 'unacceptAnswer',
        icon: 'check-square',
        title,
        className: 'accepted fade-out',
        position,
        beforeButton(h) {
          return h('span.accepted-text', I18n.t('solved.solution'));
        }
      };
    }
  });

  api.decorateWidget('post-contents:after-cooked', dec => {
    if (dec.attrs.post_number === 1) {
      const topic = dec.getModel().get('topic');
      if (topic.get('accepted_answer')) {
        return dec.rawHtml(`<p class="solved">${topic.get('acceptedAnswerHtml')}</p>`);
      }
    }
  });

  api.attachWidgetAction('post', 'acceptAnswer', function() {
    const post = this.model;
    const current = post.get('topic.postStream.posts').filter(p => {
      return p.get('post_number') === 1 || p.get('accepted_answer');
    });
    acceptPost(post);

    current.forEach(p => this.appEvents.trigger('post-stream:refresh', { id: p.id }));
  });

  api.attachWidgetAction('post', 'unacceptAnswer', function() {
    const post = this.model;
    const op = post.get('topic.postStream.posts').find(p => p.get('post_number') === 1);
    unacceptPost(post);
    this.appEvents.trigger('post-stream:refresh', { id: op.get('id') });
  });
}

export default {
  name: 'extend-for-solved-button',
  initialize() {

    Topic.reopen({
      // keeping this here cause there is complex localization
      acceptedAnswerHtml: function() {
        const username = this.get('accepted_answer.username');
        const postNumber = this.get('accepted_answer.post_number');

        if (!username || !postNumber) {
          return "";
        }

        return I18n.t("solved.accepted_html", {
          username_lower: username.toLowerCase(),
          username,
          post_path: this.get('url') + "/" + postNumber,
          post_number: postNumber,
          user_path: User.create({username: username}).get('path')
        });
      }.property('accepted_answer', 'id')
    });

    TopicStatus.reopen({
      statuses: function(){
        const results = this._super();
        if (this.topic.has_accepted_answer) {
          results.push({
            openTag: 'span',
            closeTag: 'span',
            title: I18n.t('solved.has_accepted_answer'),
            icon: 'check-square-o'
          });
        }
        return results;
      }.property()
    });

    withPluginApi('0.1', initializeWithApi, { noApi: oldPluginCode });
  }
};
