import PostMenuComponent from 'discourse/components/post-menu';
import PostView from 'discourse/views/post';
import { Button } from 'discourse/components/post-menu';
import Topic from 'discourse/models/topic';
import User from 'discourse/models/user';
import TopicStatus from 'discourse/views/topic-status';

export default {
  name: 'extend-for-solved-button',
  initialize: function() {

    Discourse.Category.reopen({
      enable_accepted_answers: function(key, value){
        if (arguments.length > 1) {
          this.set('custom_fields.enable_accepted_answers', value ? "true" : "false");
        }
        var fields = this.get('custom_fields');
        return fields && (fields.enable_accepted_answers === "true");
      }.property('custom_fields')
    });

    Topic.reopen({

      // keeping this here cause there is complex localization
      acceptedAnswerHtml: function(){
        var username = this.get('accepted_answer.username');
        var postNumber = this.get('accepted_answer.post_number');

        if (!username || !postNumber) {
          return "";
        }

        return I18n.t("solved.accepted_html", {
          username_lower: username.toLowerCase(),
          username: username,
          post_path: this.get('url') + "/" + postNumber,
          post_number: postNumber,
          user_path: User.create({username: username}).get('path')
        });
      }.property('accepted_answer', 'id')
    });

    TopicStatus.reopen({
      statuses: function(){
        var results = this._super();
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
      acceptedChanged: function(){
        this.rerender();
      }.observes('post.accepted_answer'),

      clickUnacceptAnswer: function(){
        if (!this.get('post.can_unaccept_answer')) { return; }

        this.set('post.can_accept_answer', true);
        this.set('post.can_unaccept_answer', false);
        this.set('post.accepted_answer', false);
        this.set('post.topic.accepted_answer', undefined);

        Discourse.ajax("/solution/unaccept", {
          type: 'POST',
          data: {
            id: this.get('post.id')
          }
        }).then(function(){
          //
        }).catch(function(error){
          var message = I18n.t("generic_error");
          try {
            message = $.parseJSON(error.responseText).errors;
          } catch (e) {
            // nothing we can do
          }
          bootbox.alert(message);
        });
      },

      clearAcceptedAnswer: function(){
        const posts = this.get('post.topic.postStream.posts');
        posts.forEach(function(post){
          if (post.get('post_number') > 1 ) {
            post.set('accepted_answer',false);
            post.set('can_accept_answer',true);
            post.set('can_unaccept_answer',false);
          }
        });
      },

      clickAcceptAnswer: function(){

        this.clearAcceptedAnswer();

        this.set('post.can_unaccept_answer', true);
        this.set('post.can_accept_answer', false);
        this.set('post.accepted_answer', true);

        this.set('post.topic.accepted_answer', {
          username: this.get('post.username'),
          post_number: this.get('post.post_number')
        });

        Discourse.ajax("/solution/accept", {
          type: 'POST',
          data: {
            id: this.get('post.id')
          }
        }).then(function(){
          //
        }).catch(function(error){
          var message = I18n.t("generic_error");
          try {
            message = $.parseJSON(error.responseText).errors;
          } catch (e) {
            // nothing we can do
          }
          bootbox.alert(message);
        });
      }
    });
  }
};
