(function() {
  var app;

  app = angular.module('ChainAdmin', ['ChainAdmin-Templates', 'ui.router', 'ngSanitize', 'ChainCommon', 'ChainDomainer', 'ngQuill']);

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
        controller: 'MainMenuCtrl',
        templateUrl: 'chain_admin/partials/main-menu.html'
      }).state('groupsIndex', {
        url: '/groups',
        controller: 'GroupsIndexCtrl',
        templateUrl: 'chain_admin/partials/groups/index.html'
      }).state('groupsEdit', {
        url: '/groups/:id/edit',
        controller: 'GroupsNewEditCtrl',
        templateUrl: 'chain_admin/partials/groups/new-edit.html'
      }).state('groupsNew', {
        url: '/groups/new',
        controller: 'GroupsNewEditCtrl',
        templateUrl: 'chain_admin/partials/groups/new-edit.html'
      }).state('announcementsIndex', {
        url: '/announcements',
        controller: 'AnnouncementsIndexCtrl',
        templateUrl: 'chain_admin/partials/announcements/index.html'
      }).state('announcementsEdit', {
        url: '/announcements/:id/edit',
        controller: 'AnnouncementsNewEditCtrl',
        templateUrl: 'chain_admin/partials/announcements/new-edit.html'
      }).state('announcementsNew', {
        url: '/announcements/new',
        controller: 'AnnouncementsNewEditCtrl',
        templateUrl: 'chain_admin/partials/announcements/new-edit.html'
      });
    }
  ]);

  app.constant('NG_QUILL_CONFIG', {
    modules: {
      toolbar: [
        ['bold', 'italic', 'underline', 'strike'], [
          {
            'list': 'ordered'
          }, {
            'list': 'bullet'
          }
        ], [
          {
            'script': 'sub'
          }, {
            'script': 'super'
          }
        ], [
          {
            'size': ['small', false, 'large', 'huge']
          }
        ], [
          {
            'color': []
          }, {
            'background': []
          }
        ], [
          {
            'font': []
          }
        ], ['link', 'image']
      ]
    }
  });

  app.config([
    'ngQuillConfigProvider', 'NG_QUILL_CONFIG', function(ngQuillConfigProvider, NG_QUILL_CONFIG) {
      return ngQuillConfigProvider.set(NG_QUILL_CONFIG);
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainAdmin').controller('AnnouncementsIndexCtrl', [
    '$scope', 'chainApiSvc', '$state', '$stateParams', function($scope, chainApiSvc, $state, $stateParams) {
      $scope.init = function() {
        $scope.loading = 'loading';
        return chainApiSvc.Announcement.list().then(function(data) {
          $scope.announcements = data;
          return delete $scope.loading;
        });
      };
      $scope["new"] = function() {
        return $state.go('announcementsNew');
      };
      $scope.toMain = function() {
        return $state.go('main');
      };
      if (!$scope.$root.isTest) {
        return $scope.init();
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainAdmin').controller('AnnouncementsNewEditCtrl', [
    '$scope', 'chainApiSvc', '$state', '$stateParams', function($scope, chainApiSvc, $state, $stateParams) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        if (id) {
          return chainApiSvc.Announcement.edit(id).then(function(data) {
            $scope.announcement = data;
            $scope.parseDates($scope.announcement);
            $scope.nonMembers = data.excluded_users;
            return delete $scope.loading;
          });
        } else {
          return chainApiSvc.Announcement["new"]().then(function(data) {
            $scope.announcement = {
              category: "all"
            };
            $scope.parseDates($scope.announcement);
            $scope.members = [];
            $scope.nonMembers = data.excluded_users;
            return delete $scope.loading;
          });
        }
      };
      $scope.parseDates = function(anc) {
        if (anc.start_at) {
          anc.start_at = new Date(anc.start_at);
        } else {
          anc.start_at = moment().startOf('day').add(1, 'days').toDate();
        }
        if (anc.end_at) {
          anc.end_at = new Date(anc.end_at);
        } else {
          anc.end_at = new Date(moment().endOf('day').add(1, 'days').format('Y-MM-DDTkk:mm'));
        }
        return anc;
      };
      $scope.preview = function(id) {
        if (angular.isUndefined(id)) {
          return alert("Announcement must be saved first.");
        } else {
          return chainApiSvc.Announcement.previewSave(id, {
            announcement: $scope.announcement
          }).then(function() {
            return ChainNotificationCenter.showAnnouncements([id], true);
          });
        }
      };
      $scope.save = function(id) {
        if (angular.isUndefined(id)) {
          return chainApiSvc.Announcement.create({
            announcement: $scope.announcement,
            utc_offset: $scope.utcOffsetSeconds()
          }).then(function(data) {
            alert("Announcement saved.");
            return $state.go('announcementsEdit', {
              id: data.id
            });
          });
        } else {
          return chainApiSvc.Announcement.save($scope.announcement.id, {
            announcement: $scope.announcement,
            utc_offset: $scope.utcOffsetSeconds()
          }).then(function() {
            alert("Announcement saved.");
            return $state.go('announcementsEdit', {
              id: id
            }, {
              reload: true
            });
          });
        }
      };
      $scope.utcOffsetSeconds = function() {
        return -1 * new Date().getTimezoneOffset() * 60;
      };
      $scope.disableUserSelection = function() {
        return $scope.announcement.category === 'all';
      };
      $scope["delete"] = function(id) {
        if (confirm("Delete this announcement?")) {
          return chainApiSvc.Announcement["delete"](id).then(function() {
            return $scope.toIndex();
          });
        }
      };
      $scope.toIndex = function() {
        return $state.go('announcementsIndex', {}, {
          reload: true
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainAdmin').directive('chainAdminRow', function() {
    return {
      restrict: 'A',
      replace: false,
      scope: {
        title: '@',
        path: '@',
        description: '@'
      },
      template: '<td class="label_cell"><a ng-href="{{path}}">{{title}}</a></td><td>{{description}}</td>'
    };
  });

}).call(this);

(function() {
  angular.module('ChainAdmin').controller('GroupsIndexCtrl', [
    '$scope', 'chainApiSvc', '$state', '$stateParams', function($scope, chainApiSvc, $state, $stateParams) {
      $scope.init = function() {
        $scope.loading = 'loading';
        return chainApiSvc.Group.list().then(function(data) {
          $scope.groups = data;
          return delete $scope.loading;
        });
      };
      $scope["new"] = function() {
        return $state.go('groupsNew');
      };
      $scope.toMain = function() {
        return $state.go('main');
      };
      if (!$scope.$root.isTest) {
        return $scope.init();
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainAdmin').controller('GroupsNewEditCtrl', [
    '$scope', 'groupsSvc', '$state', '$stateParams', function($scope, groupsSvc, $state, $stateParams) {
      $scope.init = function(id) {
        if (!angular.isUndefined(id)) {
          $scope.loading = 'loading';
          return groupsSvc.show(id).then(function(data) {
            $scope.group = data["group"];
            return groupsSvc.showExcludedUsers(id).then(function(data2) {
              $scope.nonMembers = data2["excluded_users"];
              return delete $scope.loading;
            });
          });
        } else {
          $scope.loading = 'loading';
          $scope.group = {};
          return groupsSvc.showExcludedUsers(id).then(function(data) {
            $scope.nonMembers = data["excluded_users"];
            return delete $scope.loading;
          });
        }
      };
      $scope.save = function(id) {
        if (angular.isUndefined(id)) {
          return groupsSvc.create($scope.group).then(function() {
            return $scope.toIndex();
          });
        } else {
          return groupsSvc.update($scope.group).then(function() {
            return $scope.toIndex();
          });
        }
      };
      $scope["delete"] = function(id) {
        return groupsSvc["delete"](id).then(function() {
          return $scope.toIndex();
        });
      };
      $scope.toIndex = function() {
        return $state.go('groupsIndex', {}, {
          reload: true
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);

(function() {
  var app;

  app = angular.module('ChainAdmin');

  app.factory('groupsSvc', [
    '$http', function($http) {
      return {
        show: function(id) {
          return $http.get("/api/v1/groups/" + id + ".json?include=users").then(function(resp) {
            return resp.data;
          });
        },
        showExcludedUsers: function(id) {
          return $http.get("/api/v1/groups/show_excluded_users/" + id).then(function(resp) {
            return resp.data;
          });
        },
        create: function(params) {
          return $http.post("/api/v1/admin/groups.json", {
            grp_system_code: params["grp_system_code"],
            grp_name: params["grp_name"],
            grp_description: params["grp_description"],
            include: "users",
            users: params["users"]
          }).then(function(resp) {
            return resp.data.group;
          });
        },
        update: function(params) {
          return $http.put("/api/v1/admin/groups/" + params['id'] + ".json", {
            id: params["id"],
            grp_name: params["grp_name"],
            grp_description: params["grp_description"],
            include: "users",
            users: params["users"]
          }).then(function(resp) {
            return resp.data.group;
          });
        },
        "delete": function(id) {
          return $http["delete"]("/api/v1/admin/groups/" + id + ".json").then(function(resp) {
            return {
              ok: "ok"
            };
          });
        }
      };
    }
  ]);

}).call(this);

angular.module("ChainAdmin-Templates", ["chain_admin/partials/announcements/index.html", "chain_admin/partials/announcements/new-edit.html", "chain_admin/partials/groups/index.html", "chain_admin/partials/groups/new-edit.html", "chain_admin/partials/main-menu.html"]);

angular.module("chain_admin/partials/announcements/index.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/announcements/index.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"col-md-12\"><h2 style=\"padding-bottom: 20px;\">VFI Track Announcements</h2><table class=\"table table-hover table-responsive\"><thead><th>Title</th><th>Start Date</th><th>Expiration Date</th></thead><tbody><tr ng-repeat=\"a in announcements | orderBy:'id':true\"><td><a ui-sref=\"announcementsEdit({id:a.id})\">{{a.title}}</a></td><td>{{a.start_at | date : 'MM/dd/yyyy, hh:mm a'}}</td><td>{{a.end_at | date : 'MM/dd/yyyy, hh:mm a'}}</td></tr></tbody></table><div class=\"row\"><div class=\"col-md-12 form-inline\"><button type=\"button\" class=\"btn btn-secondary mr-2\" ng-disabled=\"group.id\" ng-click=\"toMain()\">Back</button> <button type=\"button\" class=\"btn btn-primary\" ng-disabled=\"group.id\" ng-click=\"new()\">New</button></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_admin/partials/announcements/new-edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/announcements/new-edit.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"col-md-12\"><div class=\"row form-group\"><label for=\"input-title\" class=\"col-md-2 col-form-label font-weight-bold\">Title</label><div class=\"col-md-4\"><input id=\"input-title\" class=\"form-control\" ng-model=\"announcement.title\"></div><label for=\"input-comments\" class=\"col-md-2 col-form-label font-weight-bold\">Comments</label><div class=\"col-md-4\"><textarea id=\"input-comments\" type=\"text\" class=\"form-control\" ng-model=\"announcement.comments\"></textarea></div></div><div class=\"row form-group\"><label for=\"input-start-date\" class=\"col-md-2 col-form-label font-weight-bold\">Start Date</label><div class=\"col-md-4\"><input id=\"input-start-date\" class=\"form-control\" type=\"datetime-local\" ng-model=\"announcement.start_at\"></div></div><div class=\"row form-group\"><label for=\"input-end-at\" class=\"col-md-2 col-form-label font-weight-bold\">Expiration Date</label><div class=\"col-md-4\"><input id=\"input-end-at\" class=\"form-control\" type=\"datetime-local\" ng-model=\"announcement.end_at\"></div><legend class=\"col-md-2 col-form-label font-weight-bold\">Type</legend><fieldset class=\"form-group col-md-4\"><div class=\"form-check\"><input type=\"radio\" id=\"all-users-radio\" class=\"form-check-input\" ng-model=\"announcement.category\" value=\"all\"> <label for=\"all-users-radio\" class=\"form-check-label\">All users</label></div><div class=\"form-check\"><input type=\"radio\" id=\"selected-users-radio\" class=\"form-check-input\" ng-model=\"announcement.category\" value=\"users\"> <label for=\"selected-users-radio\" class=\"form-check-label\">Selected users</label></div></fieldset></div><chain-company-user-selector members-label=\"Recipients\" non-members-label=\"Non-Recipients\" members=\"announcement.selected_users\" non-members=\"{{nonMembers}}\" disenabled=\"announcement.category=='all'\"></chain-company-user-selector><div class=\"row form-group pt-4 pb-4\"><div class=\"col-md-12\"><label for=\"editor\" class=\"font-weight-bold\">Message</label> <small>(size limited to 1 MB)</small><ng-quill-editor id=\"editor\" ng-model=\"announcement.text\"></ng-quill-editor><small class=\"pull-right\">Warning: 'Preview' updates the announcement.</small><br><button class=\"btn btn-primary pull-right mt-1\" ng-click=\"preview(announcement.id)\">Preview</button></div></div><div class=\"row\"><div class=\"col-md-12 form-inline\"><button class=\"btn btn-secondary\" ng-click=\"toIndex()\">Back</button> <button class=\"btn btn-success mx-2\" ng-click=\"save(announcement.id)\">Save</button> <button class=\"btn btn-danger\" ng-show=\"announcement.id\" ng-click=\"delete(announcement.id)\">Delete</button></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_admin/partials/groups/index.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/groups/index.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"col-md-12\"><h2>Groups</h2><table class=\"table table-hover table-responsive\"><tr ng-repeat=\"g in groups | orderBy:'grp_name'\"><td><a ui-sref=\"groupsEdit({id:g.id})\">{{g.grp_name}}</a></td><td>{{g.grp_description}}</td></tr></table><div class=\"row\"><div class=\"col-md-12 form-inline\"><button class=\"btn mr-2\" ng-disabled=\"group.id\" ng-click=\"toMain()\">Back</button> <button class=\"btn\" ng-disabled=\"group.id\" ng-click=\"new()\">New</button></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_admin/partials/groups/new-edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/groups/new-edit.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"col-md-12\"><div class=\"row form-group\"><div class=\"col-md-2\" style=\"font-weight:bold;\">Name</div><div class=\"col-md-4\"><input class=\"form-control\" ng-model=\"group.grp_name\"></div></div><div class=\"row form-group\"><div class=\"col-md-2\" style=\"font-weight:bold;\">System Code</div><div class=\"col-md-4\"><input class=\"form-control\" ng-disabled=\"group.id\" ng-model=\"group.grp_system_code\"></div></div><div class=\"row form-group\"><div class=\"col-md-2\" style=\"font-weight:bold;\">Description</div><div class=\"col-md-4\"><input class=\"form-control col-md-10\" ng-model=\"group.grp_description\"></div></div><br><chain-company-user-selector members-label=\"Members\" non-members-label=\"Non-members\" members=\"group.users\" non-members=\"{{nonMembers}}\"></chain-company-user-selector><div class=\"row\"><div class=\"col-md-12 form-inline\"><button class=\"btn btn-secondary\" ng-click=\"toIndex()\">Back</button> <button class=\"btn btn-success mx-2\" ng-disabled=\"!group.grp_system_code || !group.grp_name\" ng-click=\"save(group.id)\">Save</button> <button class=\"btn btn-danger\" ng-show=\"group.id\" ng-click=\"delete(group.id)\">Delete</button></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_admin/partials/main-menu.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/main-menu.html",
    "<div ng-controller=\"MainMenuCtrl\"><div class=\"container\"><h1>General Settings</h1><table class=\"table table-hover table-responsive\"><tbody><tr chain-admin-row title=\"Announcements\" path=\"settings#!/announcements\" description=\"Setup announcements\"></tr><tr chain-admin-row title=\"Attachment Types\" path=\"{{paths['attachment_types']}}\" description=\"Setup the items that show in the attachment type drop down lists.\"></tr><tr chain-admin-row title=\"Business Validation Schedules\" path=\"{{paths['business_validation_schedules']}}\" description=\"Setup schedules for the automatic running of business rules.\"></tr><tr chain-admin-row title=\"Charge Codes\" path=\"{{paths['charge_codes']}}\" description=\"Setup charge codes for Brokerage Invoices.\"></tr><tr chain-admin-row title=\"Commercial Invoice Map\" path=\"{{paths['commercial_invoice_maps']}}\" description=\"Setup the mapping from Orders / Shipments to Commercial Invoices.\"></tr><tr chain-admin-row title=\"Companies\" path=\"{{paths['companies']}}\" description=\"Setup your company description or your vendors and carriers.\"></tr><tr chain-admin-row title=\"Countries\" path=\"{{paths['countries']}}\" description=\"Set options for various countries.\"></tr><tr chain-admin-row title=\"Groups\" path=\"settings#!/groups\" description=\"Configure user groups.\"></tr><tr chain-admin-row title=\"Instant Classification Setup\" path=\"{{paths['instant_classifications']}}\" description=\"Setup the rules for the Instant Classification engine.\"></tr><tr chain-admin-row title=\"Linkable Attachment Setup\" path=\"{{paths['linkable_attachment_import_rules']}}\" description=\"Setup the rules for automatically linking FTP attachments.\"></tr><tr chain-admin-row title=\"Message\" path=\"{{paths['new_bulk_messages']}}\" description=\"Send a message to one or more users.\"></tr><tr chain-admin-row title=\"Milestone Plans\" path=\"{{paths['milestone_plans']}}\" description=\"Set the milestone schedules that your products follow through your supply chain.\"></tr><tr chain-admin-row title=\"Ports\" path=\"{{paths['ports']}}\" description=\"Set codes related to ports.\"></tr><tr chain-admin-row title=\"Product Groups\" path=\"{{paths['product_groups']}}\" description=\"Configure product groups.\"></tr><tr chain-admin-row title=\"Product Types\" path=\"{{paths['entity_types']}}\" description=\"Setup product types that filter the fields shown on the product view and edit screen.\"></tr><tr chain-admin-row title=\"Regions\" path=\"{{paths['regions']}}\" description=\"Separate countries into regions.\"></tr><tr chain-admin-row title=\"Run As Logs\" path=\"{{paths['run_as_logs']}}\" description=\"View Run As Sessions\"></tr><tr chain-admin-row title=\"Search Templates\" path=\"{{paths['search_templates']}}\" description=\"Assign search templates to users.\"></tr><tr chain-admin-row title=\"Status Rules\" path=\"{{paths['status_rules']}}\" description=\"Setup the rules that determine what status a particular item has.\"></tr><tr chain-admin-row title=\"State-Toggle Buttons\" path=\"{{paths['state_toggle_buttons']}}\" description=\"Configure state-toggle buttons.\"></tr><tr chain-admin-row title=\"System Message\" path=\"{{paths['show_system_message_master_setups']}}\" description=\"Set a message that will appear on the top of every page.\"></tr><tr chain-admin-row title=\"System Summary\" path=\"{{paths['settings_system_summary']}}\" description=\"Display a printable summary of fields, validations, etc.\"></tr><tr chain-admin-row title=\"Tariff Sets\" path=\"{{paths['tariff_sets']}}\" description=\"Manage the active version of the tariff database for each country.\"></tr><tr chain-admin-row title=\"User Manuals\" path=\"{{paths['user_manuals']}}\" description=\"Upload user manuals for specific pages.\"></tr><tr chain-admin-row title=\"User Templates\" path=\"{{paths['user_templates']}}\" description=\"Setup templates for creating new users.\"></tr><tr chain-admin-row title=\"Worksheet Setups\" path=\"{{paths['worksheet_configs']}}\" description=\"Setup the file formats for the Import Worksheet buttons. These are used to upload a single Excel sheet that fills in one record's data. These are often files like a &#34;Quote Sheet&#34; or a &#34;Purchase Order&#34;.\"></tr></tbody></table><br><h1>Field Settings</h1><table class=\"table table-hover table-responsive\"><tbody><tr chain-admin-row title=\"Hard Coded Field Names\" path=\"{{paths['field_labels']}}\" description=\"Set the names for the default fields in the system.\"></tr><tr chain-admin-row title=\"Custom Fields\" path=\"{{paths['custom_definitions']}}\" description=\"Add (or change) your own field specific to your installation.\"></tr><tr chain-admin-row title=\"Public Fields\" path=\"/public_fields\" description=\"Manage the fields that are available on the public shipment search screen.\"></tr><tr chain-admin-row title=\"Field Rules\" path=\"{{paths['field_validator_rules']}}\" description=\"Manage the rules that restrict what users can enter into fields.\"></tr></tbody></table><br><div ng-show=\"isSysAdmin\"><h1>Sys Admin Settings</h1><table class=\"table table-hover table-responsive\"><tbody><tr chain-admin-row title=\"AWS Backup Sessions\" path=\"{{paths['aws_backup_sessions']}}\" description=\"View sessions and associated AWS snapshots.\"></tr><tr chain-admin-row title=\"Master Setup\" path=\"{{paths['master_setups']}}\" description=\"The master system settings (for system administrators who know what they're doing!)\"></tr><tr chain-admin-row title=\"Error Log\" path=\"{{paths['error_log_entries']}}\" description=\"System errors, nuff said.\"></tr><tr chain-admin-row title=\"Schedulable Jobs\" path=\"{{paths['schedulable_jobs']}}\" description=\"Background job schedules.\"></tr><tr chain-admin-row title=\"Custom-View Templates\" path=\"{{paths['custom_view_templates']}}\" description=\"Configure custom-view templates.\"></tr><tr chain-admin-row title=\"Search Table Configs\" path=\"{{paths['search_table_configs']}}\" description=\"Configure search-table configs.\"></tr><div ng-show=\"paths['milestone_notification_configs']\"><tr chain-admin-row title=\"315 Configurations\" path=\"{{paths['milestone_notification_configs']}}\" description=\"Entry-based 315 Configurations.\"></tr></div><div><tr chain-admin-row title=\"One-Time-Alert Reference Fields\" path=\"{{paths['alert_reference_fields']}}\" description=\"Select reference-fields available for use in one time alerts\"></tr></div></tbody></table></div></div></div>");
}]);

(function() {
  angular.module('ChainAdmin').controller('MainMenuCtrl', [
    '$scope', 'chainApiSvc', 'mainMenuSvc', function($scope, chainApiSvc, mainMenuSvc) {
      $scope.init = function() {
        mainMenuSvc.loadMenuUrls().then(function(data) {
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

(function() {
  var app;

  app = angular.module('ChainAdmin');

  app.factory('mainMenuSvc', [
    '$http', '$q', function($http, $q) {
      var cachedMe;
      cachedMe = null;
      return {
        getMenuUrls: function() {
          return $http.get('/api/v1/admin/settings/paths').then(function(resp) {
            return resp.data;
          });
        },
        loadMenuUrls: function() {
          var d;
          if (cachedMe) {
            d = $q.defer();
            d.resolve(cachedMe);
            return d.promise;
          } else {
            return this.getMenuUrls().then(function(resp) {
              return cachedMe = resp;
            });
          }
        }
      };
    }
  ]);

}).call(this);
