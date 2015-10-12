//radio
define([
	'jquery',
	'underscore',
	'backbone',
	'marionette',
	'sweetAlert',
	'translater',
	'config',
	'ns_grid/model-grid',
	'ns_modules/ns_com',
	'ns_map/ns_map',
	'ns_form/NSFormsModuleGit',
], function($, _, Backbone, Marionette, Swal, Translater, config, NsGrid, Com, NsMap, NsForm){

	'use strict';

	return Marionette.LayoutView.extend({
		/*===================================================
		=            Layout Stepper Orchestrator            =
		===================================================*/

		template: 'app/modules/validate/templates/tpl-sensorValidateDetail.html',
		className: 'full-height animated white',

		events : {
			'click button#autoValidate' : 'autoValidate',
			'change select#frequency' : 'setFrequency'
		},

		ui: {
			'grid': '#grid',
			'paginator': '#paginator',
			'totalEntries': '#totalEntries',
			'map':'#map'
		},

		initialize: function(options){
			this.translater = Translater.getTranslater();
			this.type = options.type;
			this.indId = parseInt(options.indId);
			this.sensorId = parseInt(options.sensorId);
			this.com = new Com();
			console.log(this.indId);
			console.log(this.sensorId);
		},

		onRender: function(){
			this.$el.i18n();
		},

		onShow : function(){
			this.displayGrid();
			//this.displayMap();
			//this.displayForm();
		},

		setFrequency: function(e){
			this.frequency = $(e.target).val();
		},

		displayGrid: function(){
			var cols = [{
				name: 'PK_id',
				label: 'ID',
				editable: false,
				renderable: false,
				cell : 'string'
			}, {
				name: 'date',
				label: 'Date',
				editable: false,
				cell: 'string'
			}, {
				name: 'lat',
				label: 'LAT',
				editable: false,
				cell: 'string',
			}, {
				name: 'lon',
				label: 'LON',
				editable: false,
				cell: 'string',
			}, {
				name: 'ele',
				label: 'ELE',
				editable: false,
				cell: 'string',
			},{
				name: 'speed',
				label: 'SPEED',
				editable: false,
				cell: 'string',
			}, {
				name: 'type',
				label: 'TYPE',
				editable: false,
				cell: 'string',
			}, {
				name: 'import',
				label: 'IMPORT',
				editable: true,
				cell: 'select-row',
				headerCell: 'select-all'
			}];

			var url = config.coreUrl + 'sensors/' + this.type
			+ '/uncheckedDatas/' + this.indId + '/' + this.sensorId;
			this.grid = new NsGrid({
				pagingServerSide: false,
				columns : cols,
				com: this.com,
				pageSize: 20,
				url: url,
				urlParams : this.urlParams,
				rowClicked : false,
				totalElement : 'totalEntries',
			});

			/*
			this.grid.rowClicked = function(row){
				_this.rowClicked(row);
			};
			this.grid.rowDbClicked = function(row){
				_this.rowDbClicked(row);
			};*/
			
			this.ui.grid.html(this.grid.displayGrid());
			this.ui.paginator.html(this.grid.displayPaginator());
		},

		displayMap: function(){
			var url  = config.coreUrl+ 'sensors/uncheckedDatas'+this.type_ + '/' + this.indId+'?geo=true';
			this.map = new NsMap({
				url: url,
				selection: true,
				cluster: true,
				com: this.com,
				zoom: 3,
				element : 'map',
			});
		},

		displayForm : function(){
			var url = config.coreUrl + '';
			this.nsform = new NsForm({
				name: 'IndivForm',
				modelurl: url,
				buttonRegion: [],
				formRegion: this.ui.form,
				buttonRegion: [this.ui.formBtns],
				displayMode: 'display',
				objectType: 1,
				id: this.idInd,
				reloadAfterSave : false,
				parent: this.parent
			});
		},

	});
});
