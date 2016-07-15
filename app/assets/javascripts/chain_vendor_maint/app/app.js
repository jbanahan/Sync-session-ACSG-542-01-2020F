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
      });
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainVendorMaint').directive('chainCvmNav', function() {
    return {
      restrict: 'E',
      scope: {
        activeModule: '@',
        vendor: '='
      },
      template: '<div class="row chain-cvm-nav"><div class="col-md-12 text-center"><div class="btn-group"><button class="btn btn-default" ui-sref="show({id:vendor.id})">Attributes</button><button class="btn" ui-sref="products({id:vendor.id})">Products</button><button class="btn" ui-sref="orders({id:vendor.id})">Orders</button></div></div></div>',
      replace: true,
      link: function(scope, el, attrs) {
        var btn, buttons, i, len, results;
        buttons = el.find('button');
        buttons.removeClass('btn-primary');
        buttons.removeClass('btn-default');
        results = [];
        for (i = 0, len = buttons.length; i < len; i++) {
          btn = buttons[i];
          if (btn.textContent === scope.activeModule) {
            results.push($(btn).addClass('btn-primary'));
          } else {
            results.push($(btn).addClass('btn-default'));
          }
        }
        return results;
      }
    };
  });

}).call(this);

angular.module('ChainVendorMaint-Templates', ['chain_vendor_maint/partials/orders.html', 'chain_vendor_maint/partials/products.html', 'chain_vendor_maint/partials/show.html']);

angular.module("chain_vendor_maint/partials/orders.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/orders.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Orders\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><chain-search-panel name=\"Orders\" api-object-name=\"Order\" base-search-setup-function=\"baseSearch\" page-uid=\"vendor-order\"></chain-search-panel></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_vendor_maint/partials/products.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/products.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Products\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><chain-search-panel name=\"Products\" api-object-name=\"ProductVendorAssignment\" base-search-setup-function=\"baseSearch\" page-uid=\"vendor-product\"></chain-search-panel></div></div></div></chain-loading-wrapper>");
}]);

angular.module("chain_vendor_maint/partials/show.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain_vendor_maint/partials/show.html",
    "<div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">{{vendor.cmp_name}}</h1></div><chain-cvm-nav active-module=\"Attributes\" vendor=\"vendor\"></chain-cvm-nav><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"vendor\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.Company) | chainSkipReadOnly | chainViewFields:['cmp_name','cmp_carrier','cmp_vendor','cmp_locked','cmp_customer','cmp_importer','cmp_alliance','cmp_broker','cmp_fenix','cmp_agent','cmp_factory','cmp_show_business_rules','cmp_enabled_booking_types']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-input model=\"vendor\" field=\"fld\" input-class=\"form-control\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(vendor)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(vendor)\">Save</button></div></div></div></div></div>");
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
          ]
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
    '$scope', 'chainApiSvc', '$stateParams', 'chainDomainerSvc', '$window', function($scope, chainApiSvc, $stateParams, chainDomainerSvc, $window) {
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
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);
