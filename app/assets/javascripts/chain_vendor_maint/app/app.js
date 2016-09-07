(function() {
  var app;

  app = angular.module('ChainVendorMaint', ['ChainVendorMaint-Templates', 'ui.router', 'ChainCommon', 'ChainDomainer']);

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
        controller: "MainCtrl",
        template: '<div>redirecting...</div>'
      }).state('show', {
        url: '/show/:id',
        controller: "ShowCtrl",
        templateUrl: "chain_vendor_maint/partials/show.html"
      }).state('products', {
        url: '/products/:id',
        controller: "ProductsCtrl",
        templateUrl: "chain_vendor_maint/partials/products.html"
      }).state('orders', {
        url: '/orders/:id',
        controller: "OrdersCtrl",
        templateUrl: "chain_vendor_maint/partials/orders.html"
      }).state('addresses', {
        url: '/addresses/:id',
        controller: "AddressesCtrl",
        templateUrl: "chain_vendor_maint/partials/addresses.html"
      });
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainVendorMaint').controller('AddressesCtrl', [
    '$scope', 'chainApiSvc', '$stateParams', 'chainDomainerSvc', '$window', function($scope, chainApiSvc, $stateParams, chainDomainerSvc, $window) {
      $scope.coreSearch = {};
      $scope.baseSearch = function() {
        return {
          hiddenCriteria: {
            field: 'add_comp_db_id',
            operator: 'eq',
            val: $scope.vendor.id,
            doNotSave: true
          },
          buttons: [
            {
              label: 'Edit',
              "class": 'btn btn-xs btn-default',
              iconClass: 'fa fa-pencil-square-o',
              onClick: $scope.editAddress
            }, {
              label: 'Delete',
              "class": 'btn btn-xs btn-default',
              iconClass: 'fa fa-trash',
              onClick: $scope["delete"]
            }
          ]
        };
      };
      $scope.addressToAdd = {};
      $scope.editAddress = function(address) {
        $scope.addressToEdit = address;
        $('#edit-address-modal').modal('show');
        return null;
      };
      $scope.save = function(address) {
        $('#edit-address-modal').modal('hide');
        $('#new-address-modal').modal('hide');
        $scope.loading = 'loading';
        return chainApiSvc.Address.save(address).then(function(resp) {
          if ($scope.coreSearch.searchSetup) {
            $scope.coreSearch.searchSetup.reload = new Date().getTime();
          }
          return delete $scope.loading;
        });
      };
      $scope["delete"] = function(address) {
        $scope.loading = 'loading';
        if ($window.confirm('Are you sure you want to delete this address?')) {
          return chainApiSvc.Address["delete"](address).then((function(resp) {
            if ($scope.coreSearch.searchSetup) {
              $scope.coreSearch.searchSetup.reload = new Date().getTime();
            }
            return delete $scope.loading;
          }), (function() {
            return delete $scope.loading;
          }));
        }
      };
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          var fieldUids, fld, i, len, uid;
          $scope.dict = d;
          if (d.recordTypes) {
            $scope.editFields = [];
            fieldUids = ['add_name', 'add_line_1', 'add_line_2', 'add_line_3', 'add_city', 'add_state', 'add_cntry_iso', 'add_postal_code', 'add_phone_number', 'add_fax_number', 'add_shipping'];
            for (i = 0, len = fieldUids.length; i < len; i++) {
              uid = fieldUids[i];
              fld = d.field(uid);
              if (fld.can_edit) {
                $scope.editFields.push(fld);
              }
            }
          }
          return chainApiSvc.Vendor.get(id).then(function(v) {
            $scope.vendor = v;
            $scope.addressToAdd.add_comp_db_id = v.id;
            return delete $scope.loading;
          });
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainVendorMaint').directive('chainCvmNav', [
    'chainApiSvc', '$window', function(chainApiSvc, $window) {
      return {
        restrict: 'E',
        scope: {
          activeModule: '@',
          vendor: '='
        },
        templateUrl: 'chain_vendor_maint/partials/chain-cvm-nav.html',
        replace: true,
        link: function(scope, el, attrs) {
          var btn, buttons, i, len;
          buttons = el.find('button');
          buttons.removeClass('btn-primary');
          buttons.removeClass('btn-default');
          scope.isAdmin = false;
          chainApiSvc.User.me().then(function(u) {
            return scope.isAdmin = u.permissions.admin;
          });
          for (i = 0, len = buttons.length; i < len; i++) {
            btn = buttons[i];
            if (btn.textContent === scope.activeModule) {
              $(btn).addClass('btn-primary');
            } else {
              $(btn).addClass('btn-default');
            }
          }
          return scope.goToUsers = function(id) {
            return $window.location.href = '/companies/' + id + '/users';
          };
        }
      };
    }
  ]);

}).call(this);

angular.module('ChainVendorMaint-Templates', ['chain_vendor_maint/partials/addresses.html', 'chain_vendor_maint/partials/chain-cvm-nav.html', 'chain_vendor_maint/partials/orders.html', 'chain_vendor_maint/partials/products.html', 'chain_vendor_maint/partials/show.html']);

angular.module("chain_vendor_maint/partials/addresses.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/addresses.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Addresses\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><chain-search-panel name=\"Addresses\" api-object-name=\"Address\" base-search-setup-function=\"baseSearch\" page-uid=\"vendor-address\" bulk-edit=\"true\"></chain-search-panel></div></div><div class=\"row\"><div class=\"col-md-12 text-right\"><button ng-if=\"vendor.permissions.can_edit\" class=\"btn btn-success\" title=\"Add Address\" data-toggle=\"modal\" data-target=\"#new-address-modal\"><i class=\"fa fa-plus\"></i></button></div></div></div></chain-loading-wrapper><div class=\"modal fade\" data-keyboard=\"false\" data-backdrop=\"static\" id=\"edit-address-modal\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Edit Address</h4></div><div class=\"modal-body\" ng-if=\"addressToEdit\"><div ng-if=\"vendor.permissions.can_edit\"><chain-field-label field=\"dict.field(&quot;add_shipping&quot;)\"></chain-field-label><chain-field-input model=\"addressToEdit\" field=\"dict.field(&quot;add_shipping&quot;)\" input-class=\"form-control\"></chain-field-input></div><div ng-if=\"!vendor.permissions.can_edit\"><div class=\"alert alert-info\">You do not have permission to edit addresses for this vendor.</div></div></div><div class=\"modal-footer text-right\"><button class=\"btn btn-default\" data-dismiss=\"modal\">Cancel</button> <button ng-if=\"vendor.permissions.can_edit\" ng-click=\"save(addressToEdit)\" class=\"btn btn-success\" title=\"Save\"><i class=\"fa fa-save\"></i></button></div></div></div></div><div class=\"modal fade\" data-keyboard=\"false\" data-backdrop=\"static\" id=\"new-address-modal\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">New Address</h4></div><div class=\"modal-body\" ng-if=\"addressToAdd.add_comp_db_id\"><div ng-repeat=\"f in editFields track by f.uid\"><chain-field-label field=\"f\"></chain-field-label><chain-field-input model=\"addressToAdd\" field=\"f\" input-class=\"form-control\"></chain-field-input></div></div><div class=\"modal-footer text-right\"><button class=\"btn btn-default\" data-dismiss=\"modal\">Cancel</button> <button ng-click=\"save(addressToAdd)\" class=\"btn btn-success\" title=\"Save\"><i class=\"fa fa-save\"></i></button></div></div></div></div>");
}]);

angular.module("chain_vendor_maint/partials/chain-cvm-nav.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/chain-cvm-nav.html",
    "<div class=\"row chain-cvm-nav\"><div class=\"col-md-12 text-center\"><div class=\"btn-group\"><button class=\"btn btn-default\" ui-sref=\"show({id:vendor.id})\">Attributes</button> <button class=\"btn\" ui-sref=\"addresses({id:vendor.id})\">Addresses</button> <button class=\"btn\" ui-sref=\"products({id:vendor.id})\">Products</button> <button class=\"btn\" ui-sref=\"orders({id:vendor.id})\">Orders</button> <button class=\"btn\" ng-show=\"isAdmin\" ng-click=\"goToUsers(vendor.id)\">Users</button></div></div></div>");
}]);

angular.module("chain_vendor_maint/partials/orders.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/orders.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Orders\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><chain-search-panel name=\"Orders\" api-object-name=\"Order\" base-search-setup-function=\"baseSearch\" page-uid=\"vendor-order\" bulk-edit=\"true\"></chain-search-panel></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_vendor_maint/partials/products.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/products.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Products\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><chain-search-panel name=\"Products\" api-object-name=\"ProductVendorAssignment\" base-search-setup-function=\"baseSearch\" page-uid=\"{{pageUid}}\" bulk-edit=\"true\"></chain-search-panel></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_vendor_maint/partials/show.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/show.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Attributes\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"vendor\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.Company) | chainViewFields:hiddenFields:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-input model=\"vendor\" field=\"fld\" input-class=\"form-control\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><chain-state-toggle-buttons toggle-callback=\"reload\" button-classes=\"btn-sm\" api-object-name=\"Vendor\" object=\"vendor\"></chain-state-toggle-buttons><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(vendor)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(vendor)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

(function() {
  angular.module('ChainVendorMaint').controller('MainCtrl', [
    '$scope', '$location', '$state', function($scope, $location, $state) {
      var i, len, results, s, seg, segments, transitioned, url;
      url = $location.absUrl();
      segments = url.split('/');
      transitioned = false;
      results = [];
      for (i = 0, len = segments.length; i < len; i++) {
        seg = segments[i];
        s = seg.replace('#', '');
        if (!transitioned && s.match(/^[0-9]+$/)) {
          transitioned = true;
          console.log('transitioning to ' + s);
          results.push($state.transitionTo('show', {
            id: s
          }));
        } else {
          results.push(void 0);
        }
      }
      return results;
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainVendorMaint').controller('OrdersCtrl', [
    '$scope', 'chainApiSvc', '$stateParams', 'chainDomainerSvc', '$window', function($scope, chainApiSvc, $stateParams, chainDomainerSvc, $window) {
      $scope.coreSearch = {};
      $scope.baseSearch = function() {
        return {
          hiddenCriteria: {
            field: 'ord_vendor_id',
            operator: 'eq',
            val: $scope.vendor.id,
            doNotSave: true
          },
          buttons: [
            {
              label: 'View',
              "class": 'btn btn-xs btn-default',
              iconClass: 'fa fa-eye',
              onClick: $scope.showOrder
            }
          ],
          bulkSelections: true
        };
      };
      $scope.showOrder = function(order) {
        return $window.location.href = '/orders/' + order.id;
      };
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.Vendor.get(id).then(function(v) {
            $scope.vendor = v;
            return delete $scope.loading;
          });
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainVendorMaint').controller('ProductsCtrl', [
    '$scope', 'chainApiSvc', '$stateParams', 'chainDomainerSvc', '$window', 'bulkSelectionSvc', function($scope, chainApiSvc, $stateParams, chainDomainerSvc, $window, bulkSelectionSvc) {
      $scope.pageUid = 'vendor-product';
      $scope.coreSearch = {};
      $scope.baseSearch = function() {
        var ss;
        return ss = {
          hiddenCriteria: {
            field: 'prodven_vend_dbid',
            operator: 'eq',
            val: $scope.vendor.id,
            doNotSave: true
          },
          buttons: [
            {
              label: 'View',
              "class": 'btn btn-xs btn-default',
              iconClass: 'fa fa-eye',
              onClick: $scope.showProduct
            }
          ],
          bulkSelections: true
        };
      };
      $scope.isBulkSelected = function() {
        return bulkSelectionSvc.selectedCount($scope.pageUid) > 0;
      };
      $scope.showProduct = function(pva) {
        return $window.location.href = '/products/' + pva.product_id;
      };
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.Vendor.get(id).then(function(v) {
            $scope.vendor = v;
            return delete $scope.loading;
          });
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainVendorMaint').controller('ShowCtrl', [
    '$scope', 'chainApiSvc', '$stateParams', 'chainDomainerSvc', function($scope, chainApiSvc, $stateParams, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.Vendor.get(id).then(function(v) {
            $scope.vendor = v;
            return delete $scope.loading;
          });
        });
      };
      $scope.save = function(vendor) {
        $scope.loading = 'loading';
        return chainApiSvc.Vendor.save(vendor).then(function(v) {
          return $scope.init(vendor.id);
        });
      };
      $scope.cancel = function(vendor) {
        $scope.loading = 'loading';
        return chainApiSvc.Vendor.load(vendor.id).then(function(v) {
          $scope.vendor = v;
          return delete $scope.loading;
        });
      };
      $scope.reload = function() {
        return $scope.cancel($scope.vendor);
      };
      $scope.hiddenFields = ['cmp_name', 'cmp_carrier', 'cmp_vendor', 'cmp_locked', 'cmp_customer', 'cmp_importer', 'cmp_alliance', 'cmp_broker', 'cmp_fenix', 'cmp_agent', 'cmp_factory', 'comp_show_buiness_rules', 'cmp_enabled_booking_types', 'cmp_attachment_types', 'cmp_attachment_count', 'cmp_attachment_filenames', 'cmp_failed_business_rules', 'cmp_review_business_rules', 'comp_show_business_rules', 'cmp_rule_state', 'cmp_slack_channel'];
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);
