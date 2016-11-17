(function() {
  var app;

  app = angular.module('ChainAdmin', ['ChainAdmin-Templates', 'ui.router', 'ChainCommon', 'ChainDomainer']);

  app.config([
    '$httpProvider', function($httpProvider) {
      return $httpProvider.defaults.headers.common['Accept'] = 'application/json';
    }
  ]);

  app.config([
    '$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $urlRouterProvider.otherwise('/');
      return $stateProvider.state('main', {
        url: '/',
        controller: 'mainMenuCtrl',
        templateUrl: 'chain_admin/main.html'
      });
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainAdmin').directive('chainAdminRow', function() {
    return {
      restrict: 'E',
      scope: {
        title: '@',
        path: '@',
        description: '@'
      },
      replace: true,
      template: '<tr class="hover field-row"><td class="label_cell"><a href="{{path}}"">{{title}}</a>:</td><td>{{description}}</td></tr>'
    };
  });

}).call(this);

angular.module('ChainAdmin-Templates', ['chain_admin/main.html']);

angular.module("chain_admin/main.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/main.html",
    "<div ng-controller=\"mainMenuCtrl\"><h1>General Settings</h1><table><chain-admin-row title=\"Attachment Types\" path=\"{{paths['attachment_types']}}\" description=\"Setup the items that show in the attachment type drop down lists.\"></chain-admin-row><chain-admin-row title=\"Charge Codes\" path=\"{{paths['charge_codes']}}\" description=\"Setup charge codes for Brokerage Invoices.\"></chain-admin-row><chain-admin-row title=\"Commercial Invoice Map\" path=\"{{paths['commercial_invoice_maps']}}\" description=\"Setup the mapping from Orders / Shipments to Commercial Invoices.\"></chain-admin-row><chain-admin-row title=\"Companies\" path=\"{{paths['companies']}}\" description=\"Setup your company description or your vendors and carriers.\"></chain-admin-row><chain-admin-row title=\"Countries\" path=\"{{paths['countries']}}\" description=\"Set options for various countries.\"></chain-admin-row><chain-admin-row title=\"Groups\" path=\"{{paths['groups']}}\" description=\"Configure user groups.\"></chain-admin-row><chain-admin-row title=\"Instant Classification Setup\" path=\"{{paths['instant_classifications']}}\" description=\"Setup the rules for the Instant Classification engine.\"></chain-admin-row><chain-admin-row title=\"Linkable Attachment Setup\" path=\"{{paths['linkable_attachment_import_rules']}}\" description=\"Setup the rules for automatically linking FTP attachments.\"></chain-admin-row><chain-admin-row title=\"Message\" path=\"{{paths['new_bulk_messages']}}\" description=\"Send a message to one or more users.\"></chain-admin-row><chain-admin-row title=\"Milestone Plans\" path=\"{{paths['milestone_plans']}}\" description=\"Set the milestone schedules that your products follow through your supply chain.\"></chain-admin-row><chain-admin-row title=\"Ports\" path=\"{{paths['ports']}}\" description=\"Set codes related to ports.\"></chain-admin-row><chain-admin-row title=\"Product Groups\" path=\"{{paths['product_groups']}}\" description=\"Configure product groups.\"></chain-admin-row><chain-admin-row title=\"Product Types\" path=\"{{paths['entity_types']}}\" description=\"Setup product types that filter the fields shown on the product view and edit screen.\"></chain-admin-row><chain-admin-row title=\"Regions\" path=\"{{paths['regions']}}\" description=\"Separate countries into regions.\"></chain-admin-row><chain-admin-row title=\"Search Templates\" path=\"{{paths['search_templates']}}\" description=\"Assign search templates to users.\"></chain-admin-row><chain-admin-row title=\"Status Rules\" path=\"{{paths['status_rules']}}\" description=\"Setup the rules that determine what status a particular item has.\"></chain-admin-row><chain-admin-row title=\"System Message\" path=\"{{paths['show_system_message_master_setups']}}\" description=\"Set a message that will appear on the top of every page.\"></chain-admin-row><chain-admin-row title=\"System Summary\" path=\"{{paths['settings_system_summary']}}\" description=\"Display a printable summary of fields, validations, etc.\"></chain-admin-row><chain-admin-row title=\"Tariff Sets\" path=\"{{paths['tariff_sets']}}\" description=\"Manage the active version of the tariff database for each country.\"></chain-admin-row><chain-admin-row title=\"User Manuals\" path=\"{{paths['user_manuals']}}\" description=\"Upload user manuals for specific pages.\"></chain-admin-row><chain-admin-row title=\"User Templates\" path=\"{{paths['user_templates']}}\" description=\"Setup templates for creating new users.\"></chain-admin-row><chain-admin-row title=\"Worksheet Setups\" path=\"{{paths['worksheet_configs']}}\" description=\"Setup the file formats for the Import Worksheet buttons. These are used to upload a single Excel sheet that fills in one record's data. These are often files like a &#34;Quote Sheet&#34; or a &#34;Purchase Order&#34;.\"></chain-admin-row></table><h1>Field Settings</h1><table><chain-admin-row title=\"Hard Coded Field Names\" path=\"{{paths['field_labels']}}\" description=\"Set the names for the default fields in the system.\"></chain-admin-row><chain-admin-row title=\"Custom Fields\" path=\"{{paths['custom_definitions']}}\" description=\"Add (or change) your own field specific to your installation.\"></chain-admin-row><chain-admin-row title=\"Public Fields\" path=\"/public_fields\" description=\"Manage the fields that are available on the public shipment search screen.\"></chain-admin-row><chain-admin-row title=\"Field Rules\" path=\"{{paths['field_validator_rules']}}\" description=\"Manage the rules that restrict what users can enter into fields.\"></chain-admin-row></table><div ng-show=\"isSysAdmin\"><h1>Sys Admin Settings</h1><table><chain-admin-row title=\"Master Setup\" path=\"{{paths['master_setups']}}\" description=\"The master system settings (for system administrators who know what they're doing!)\"></chain-admin-row><chain-admin-row title=\"Error Log\" path=\"{{paths['error_log_entries']}}\" description=\"System errors, nuff said.\"></chain-admin-row><chain-admin-row title=\"Schedulable Jobs\" path=\"{{paths['schedulable_jobs']}}\" description=\"Background job schedules.\"></chain-admin-row><chain-admin-row title=\"Custom-View Templates\" path=\"{{paths['custom_view_templates']}}\" description=\"Configure custom-view templates.\"></chain-admin-row><chain-admin-row title=\"State-Toggle Buttons\" path=\"{{paths['state_toggle_buttons']}}\" description=\"Configure state-toggle buttons.\"></chain-admin-row><chain-admin-row title=\"Search Table Configs\" path=\"{{paths['search_table_configs']}}\" description=\"Configure search-table configs.\"></chain-admin-row><div ng-show=\"paths['milestone_notification_configs']\"><chain-admin-row title=\"315 Configurations\" path=\"{{paths['milestone_notification_configs']}}\" description=\"Entry-based 315 Configurations.\"></chain-admin-row></div></table></div></div>");
}]);

(function() {
  angular.module('ChainAdmin').controller('mainMenuCtrl', [
    '$scope', 'chainApiSvc', function($scope, chainApiSvc) {
      $scope.init = function() {
        chainApiSvc.Admin.loadMenuUrls().then(function(data) {
          return $scope.paths = data;
        });
        return chainApiSvc.User.me().then(function(u) {
          return $scope.isSysAdmin = u.permissions.sys_admin;
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init();
      }
    }
  ]);

}).call(this);
