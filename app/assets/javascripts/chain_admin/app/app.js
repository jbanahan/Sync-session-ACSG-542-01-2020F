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
      });
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
      template: '<td class="label_cell"><a href="{{path}}"">{{title}}</a></td><td>{{description}}</td>'
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

(function() {
  angular.module('ChainAdmin').directive('groupsUserSelector', [
    function() {
      return {
        restrict: 'E',
        scope: {
          members: '=',
          nonMembers: '@'
        },
        templateUrl: 'chain_admin/partials/groups/groups-user-selector.html',
        link: function(scope, element, attrs) {
          scope.init = function(el) {
            scope.membersBox = $(el).find('#members-select');
            scope.nonMembersBox = $(el).find('#non-members-select');
            scope.membersById = {};
            if (scope.members) {
              scope.membersById = scope.hashifyUserArray(scope.members);
            }
            if (scope.nonMembers) {
              scope.nonMembersById = scope.hashifyUserArray(angular.fromJson(scope.nonMembers));
            }
            scope.updateMemberIds();
            return scope.updateBoxes();
          };
          scope.hashifyUserArray = function(arr) {
            var i, len, m, out;
            out = {};
            for (i = 0, len = arr.length; i < len; i++) {
              m = arr[i];
              out[m.id] = m;
            }
            return out;
          };
          scope.getIds = function(selector) {
            var i, idArr, len, optionTag, ref;
            idArr = [];
            ref = $(selector);
            for (i = 0, len = ref.length; i < len; i++) {
              optionTag = ref[i];
              idArr.push($(optionTag).attr("value"));
            }
            return idArr;
          };
          scope.add = function() {
            scope.addMembers();
            return scope.updateBoxes();
          };
          scope.remove = function() {
            scope.removeMembers();
            return scope.updateBoxes();
          };
          scope.addMembers = function() {
            var ids;
            ids = scope.getIds(scope.nonMembersBox.find("option:selected"));
            scope.moveMembers(ids, scope.nonMembersById, scope.membersById);
            return scope.updateMemberIds();
          };
          scope.removeMembers = function() {
            var ids;
            ids = scope.getIds(scope.membersBox.find("option:selected"));
            scope.moveMembers(ids, scope.membersById, scope.nonMembersById);
            return scope.updateMemberIds();
          };
          scope.moveMembers = function(idArr, fromModel, toModel) {
            var i, id, len, results;
            results = [];
            for (i = 0, len = idArr.length; i < len; i++) {
              id = idArr[i];
              toModel[id] = fromModel[id];
              results.push(delete fromModel[id]);
            }
            return results;
          };
          scope.updateMemberIds = function() {
            return scope.members = Object.keys(scope.membersById);
          };
          scope.updateBoxes = function() {
            scope.write(scope.membersById, scope.membersBox);
            return scope.write(scope.nonMembersById, scope.nonMembersBox);
          };
          scope.write = function(model, selectTag) {
            var c, coNames, i, len, optGroupTag, optUserTag, results, u, usersByCo;
            usersByCo = scope.usersByCo(model);
            coNames = Object.keys(usersByCo).sort();
            selectTag.children('optgroup').remove();
            results = [];
            for (i = 0, len = coNames.length; i < len; i++) {
              c = coNames[i];
              scope.sortByUserName(usersByCo[c]);
              optGroupTag = $("<optgroup label='" + c + "'></optgroup");
              selectTag.append(optGroupTag);
              results.push((function() {
                var j, len1, ref, results1;
                ref = usersByCo[c];
                results1 = [];
                for (j = 0, len1 = ref.length; j < len1; j++) {
                  u = ref[j];
                  optUserTag = "<option value='" + u.id + "'>" + u.full_name + " (" + u.email + ")</option>";
                  results1.push(optGroupTag.append(optUserTag));
                }
                return results1;
              })());
            }
            return results;
          };
          scope.usersByCo = function(model) {
            var out, u, uid, userCo;
            out = {};
            for (uid in model) {
              u = model[uid];
              userCo = u.company.name;
              if (out[userCo]) {
                out[userCo].push(u);
              } else {
                out[userCo] = [u];
              }
            }
            return out;
          };
          scope.sortByUserName = function(users) {
            return users.sort(function(u1, u2) {
              return u1.full_name.toUpperCase() > u2.full_name.toUpperCase();
            });
          };
          return scope.init(element);
        }
      };
    }
  ]);

}).call(this);

angular.module('ChainAdmin-Templates', ['chain_admin/partials/groups/groups-user-selector.html', 'chain_admin/partials/groups/index.html', 'chain_admin/partials/groups/new-edit.html', 'chain_admin/partials/main-menu.html']);

angular.module("chain_admin/partials/groups/groups-user-selector.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/groups/groups-user-selector.html",
    "<div class=\"container\"><div class=\"row\"><div class=\"col-md-5\"><div class=\"form-group\"><label>Non-members</label><select name=\"Non-Members\" id=\"non-members-select\" class=\"form-control\" size=\"10\" multiple></select></div></div><div class=\"col-md-2\"><div style=\"display: table; margin-top: 2.5em; width: 100%\"><div style=\"display: table-cell; text-align: center\"><div style=\"display: inline-block\"><button class=\"form-control btn btn-default\" id=\"btn-assign-groups\" ng-click=\"add()\"><span class=\"glyphicon glyphicon-chevron-right\" aria-hidden=\"true\"></span></button> <button class=\"form-control btn btn-default\" style=\"margin-top: 1em\" id=\"btn-remove-groups\" ng-click=\"remove()\"><span class=\"glyphicon glyphicon-chevron-left\" aria-hidden=\"true\"></span></button></div></div></div></div><div class=\"col-md-5\"><div class=\"form-group\"><label>Members</label><select name=\"Members\" id=\"members-select\" class=\"form-control\" size=\"10\" multiple></select><input id=\"members-list\" name=\"members_list\" type=\"hidden\"></div></div></div></div>");
}]);

angular.module("chain_admin/partials/groups/index.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/groups/index.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"col-md-12\"><h2>Groups</h2><table class=\"table table-hover table-responsive\"><tr ng-repeat=\"g in groups | orderBy:'grp_name'\"><td><a ui-sref=\"groupsEdit({id:g.id})\">{{g.grp_name}}</a></td><td>{{g.grp_description}}</td></tr></table><div class=\"row\"><div class=\"col-md-12 form-inline\"><button class=\"btn btn-default\" ng-disabled=\"group.id\" ng-click=\"toMain()\">Back</button> <button class=\"btn btn-default\" ng-disabled=\"group.id\" ng-click=\"new()\">New</button></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_admin/partials/groups/new-edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/groups/new-edit.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"col-md-12\"><div class=\"row form-group\"><div class=\"col-md-2\" style=\"font-weight:bold\">Name</div><div class=\"col-md-4\"><input class=\"form-control\" ng-model=\"group.grp_name\"></div></div><div class=\"row form-group\"><div class=\"col-md-2\" style=\"font-weight:bold\">System Code</div><div class=\"col-md-4\"><input class=\"form-control\" ng-disabled=\"group.id\" ng-model=\"group.grp_system_code\"></div></div><div class=\"row form-group\"><div class=\"col-md-2\" style=\"font-weight:bold\">Description</div><div class=\"col-md-4\"><input class=\"form-control col-md-10\" ng-model=\"group.grp_description\"></div></div><br><div class=\"row\"><groups-user-selector members=\"group.users\" non-members=\"{{nonMembers}}\"></groups-user-selector></div><div class=\"row\"><div class=\"col-md-12 form-inline\"><button class=\"btn btn-default\" ng-click=\"toIndex()\">Back</button> <button class=\"btn btn-default\" ng-disabled=\"!group.grp_system_code || !group.grp_name\" ng-click=\"save(group.id)\">Save</button> <button class=\"btn btn-default\" ng-show=\"group.id\" ng-click=\"delete(group.id)\">Delete</button></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_admin/partials/main-menu.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_admin/partials/main-menu.html",
    "<div ng-controller=\"MainMenuCtrl\"><div class=\"container\"><h1>General Settings</h1><table class=\"table table-hover table-responsive\"><thead><tr><th class=\"col-md-3\"></th><th class=\"cold-md-8\"></th></tr></thead><tbody><tr chain-admin-row title=\"Attachment Types\" path=\"{{paths['attachment_types']}}\" description=\"Setup the items that show in the attachment type drop down lists.\"></tr><tr chain-admin-row title=\"Charge Codes\" path=\"{{paths['charge_codes']}}\" description=\"Setup charge codes for Brokerage Invoices.\"></tr><tr chain-admin-row title=\"Commercial Invoice Map\" path=\"{{paths['commercial_invoice_maps']}}\" description=\"Setup the mapping from Orders / Shipments to Commercial Invoices.\"></tr><tr chain-admin-row title=\"Companies\" path=\"{{paths['companies']}}\" description=\"Setup your company description or your vendors and carriers.\"></tr><tr chain-admin-row title=\"Countries\" path=\"{{paths['countries']}}\" description=\"Set options for various countries.\"></tr><tr chain-admin-row title=\"Groups\" path=\"settings#/groups\" description=\"Configure user groups.\"></tr><tr chain-admin-row title=\"Instant Classification Setup\" path=\"{{paths['instant_classifications']}}\" description=\"Setup the rules for the Instant Classification engine.\"></tr><tr chain-admin-row title=\"Linkable Attachment Setup\" path=\"{{paths['linkable_attachment_import_rules']}}\" description=\"Setup the rules for automatically linking FTP attachments.\"></tr><tr chain-admin-row title=\"Message\" path=\"{{paths['new_bulk_messages']}}\" description=\"Send a message to one or more users.\"></tr><tr chain-admin-row title=\"Milestone Plans\" path=\"{{paths['milestone_plans']}}\" description=\"Set the milestone schedules that your products follow through your supply chain.\"></tr><tr chain-admin-row title=\"Ports\" path=\"{{paths['ports']}}\" description=\"Set codes related to ports.\"></tr><tr chain-admin-row title=\"Product Groups\" path=\"{{paths['product_groups']}}\" description=\"Configure product groups.\"></tr><tr chain-admin-row title=\"Product Types\" path=\"{{paths['entity_types']}}\" description=\"Setup product types that filter the fields shown on the product view and edit screen.\"></tr><tr chain-admin-row title=\"Regions\" path=\"{{paths['regions']}}\" description=\"Separate countries into regions.\"></tr><tr chain-admin-row title=\"Search Templates\" path=\"{{paths['search_templates']}}\" description=\"Assign search templates to users.\"></tr><tr chain-admin-row title=\"Status Rules\" path=\"{{paths['status_rules']}}\" description=\"Setup the rules that determine what status a particular item has.\"></tr><tr chain-admin-row title=\"State-Toggle Buttons\" path=\"{{paths['state_toggle_buttons']}}\" description=\"Configure state-toggle buttons.\"></tr><tr chain-admin-row title=\"System Message\" path=\"{{paths['show_system_message_master_setups']}}\" description=\"Set a message that will appear on the top of every page.\"></tr><tr chain-admin-row title=\"System Summary\" path=\"{{paths['settings_system_summary']}}\" description=\"Display a printable summary of fields, validations, etc.\"></tr><tr chain-admin-row title=\"Tariff Sets\" path=\"{{paths['tariff_sets']}}\" description=\"Manage the active version of the tariff database for each country.\"></tr><tr chain-admin-row title=\"User Manuals\" path=\"{{paths['user_manuals']}}\" description=\"Upload user manuals for specific pages.\"></tr><tr chain-admin-row title=\"User Templates\" path=\"{{paths['user_templates']}}\" description=\"Setup templates for creating new users.\"></tr><tr chain-admin-row title=\"Worksheet Setups\" path=\"{{paths['worksheet_configs']}}\" description=\"Setup the file formats for the Import Worksheet buttons. These are used to upload a single Excel sheet that fills in one record's data. These are often files like a &#34;Quote Sheet&#34; or a &#34;Purchase Order&#34;.\"></tr></tbody></table><br><h1>Field Settings</h1><table class=\"table table-hover table-responsive\"><thead><tr><th class=\"col-md-3\"></th><th class=\"cold-md-8\"></th></tr></thead><tbody><tr chain-admin-row title=\"Hard Coded Field Names\" path=\"{{paths['field_labels']}}\" description=\"Set the names for the default fields in the system.\"></tr><tr chain-admin-row title=\"Custom Fields\" path=\"{{paths['custom_definitions']}}\" description=\"Add (or change) your own field specific to your installation.\"></tr><tr chain-admin-row title=\"Public Fields\" path=\"/public_fields\" description=\"Manage the fields that are available on the public shipment search screen.\"></tr><tr chain-admin-row title=\"Field Rules\" path=\"{{paths['field_validator_rules']}}\" description=\"Manage the rules that restrict what users can enter into fields.\"></tr></tbody></table><br><div ng-show=\"isSysAdmin\"><h1>Sys Admin Settings</h1><table class=\"table table-hover table-responsive\"><thead><tr><th class=\"col-md-3\"></th><th class=\"cold-md-8\"></th></tr></thead><tbody><tr chain-admin-row title=\"AWS Backup Sessions\" path=\"{{paths['aws_backup_sessions']}}\" description=\"View sessions and associated AWS snapshots.\"></tr><tr chain-admin-row title=\"Master Setup\" path=\"{{paths['master_setups']}}\" description=\"The master system settings (for system administrators who know what they're doing!)\"></tr><tr chain-admin-row title=\"Error Log\" path=\"{{paths['error_log_entries']}}\" description=\"System errors, nuff said.\"></tr><tr chain-admin-row title=\"Schedulable Jobs\" path=\"{{paths['schedulable_jobs']}}\" description=\"Background job schedules.\"></tr><tr chain-admin-row title=\"Custom-View Templates\" path=\"{{paths['custom_view_templates']}}\" description=\"Configure custom-view templates.\"></tr><tr chain-admin-row title=\"Search Table Configs\" path=\"{{paths['search_table_configs']}}\" description=\"Configure search-table configs.\"></tr><div ng-show=\"paths['milestone_notification_configs']\"><tr chain-admin-row title=\"315 Configurations\" path=\"{{paths['milestone_notification_configs']}}\" description=\"Entry-based 315 Configurations.\"></tr></div></tbody></table></div></div></div>");
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
