define([
	'jquery',
	'underscore',
	'backbone',
	'marionette',
	'sweetAlert',
	'translater',
	'ns_form/NSFormsModuleGit',
], function(
  $, _, Backbone, Marionette, Swal, Translater,
  NsForm
){

  'use strict';
  return Marionette.ItemView.extend({
    template: 'app/modules/objects/object.new.tpl.html',
    className: 'white full-height new',

    ui: {
      'form': '.js-form',
    },
    events: {
      'click .js-btn-save': 'save',
      'click .js-link-back': 'back',
    },
    
    model: new Backbone.Model(),

    initialize: function(options) {
      this.model.set('objectType', options.objectType || 1);
    },

    onShow: function() {
      this.displayForm();
    },

    displayForm: function() {
      var _this = this;
      this.nsForm = new NsForm({
        modelurl: this.model.get('type'),
        buttonRegion: [],
        formRegion: this.ui.form,
        displayMode: 'edit',
        objectType: this.model.get('objectType'),
        id: 0,
        reloadAfterSave: false,
        afterSaveSuccess: this.afterSaveSuccess.bind(this),
        savingError: function(response) {
          var msg = 'in creating a new sensor';
          if (response.status == 520 && response.responseText){
            msg = response.responseText;
          }
          Swal({
            title: 'Error',
            text: msg ,
            type: 'error',
            showCancelButton: false,
            confirmButtonColor: 'rgb(147, 14, 14)',
            confirmButtonText: 'OK',
            closeOnConfirm: true,
          });
        }
      });
    },

    afterSaveSuccess: function(){
      var _this = this;
      swal({
        title: 'Succes',
        text: 'creating new sensor',
        type: 'success',
        showCancelButton: true,
        confirmButtonColor: 'green',
        confirmButtonText: 'create another sensor',
        cancelButtonText: 'cancel',
        closeOnConfirm: true,
      },
      function(isConfirm) {
        if (!isConfirm) {
          _this.cancel();
        } else {
          _this.nsForm.butClickClear();
        }
      });
    },

    save: function() {
      this.nsForm.butClickSave();
    },

    back: function() {
    },
  });
});
