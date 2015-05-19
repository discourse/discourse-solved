import PostMenuView from 'discourse/views/post-menu';
import PostView from 'discourse/views/post';
import { Button } from 'discourse/views/post-menu';
import Topic from 'discourse/models/topic';

export default {
  name: 'extend-for-solved-button',
  initialize: function() {

    Topic.reopen({
      // keeping this here cause there is complex localization
      acceptedAnswerHtml: function(){
        return I18n.t("")
      }.property('accepted_answer')
    });

    PostView.reopen({
      classNameBindings: ['post.accepted_answer:accepted-answer']
    });

    PostMenuView.registerButton(function(visibleButtons){
      if (this.get('post.can_accept_answer')) {
        visibleButtons.splice(0,0,new Button('acceptAnswer', 'accepted_answer.accept_answer', 'check-square-o', {className: 'unaccepted'}));
      }
      if (this.get('post.can_unaccept_answer')) {
        visibleButtons.splice(0,0,new Button('unacceptAnswer', 'accepted_answer.unaccept_answer', 'check-square', {className: 'accepted'}));
      }
    });

    PostMenuView.reopen({
      acceptedChanged: function(){
        this.rerender();
      }.observes('post.accepted_answer'),

      clickUnacceptAnswer: function(){
        this.set('post.can_accept_answer', true);
        this.set('post.can_unaccept_answer', false);
        this.set('post.topic.has_accepted_answer', false);

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
