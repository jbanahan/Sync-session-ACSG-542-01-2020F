(function() {
  var app;

  app = angular.module('VendorPortal', ['ui.router', 'ChainCommon', 'ChainDomainer']);

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
        templateUrl: "/vendor_portal/partials/main.html"
      }).state('showOrder', {
        url: '/orders/:id',
        template: "<chain-loading-wrapper loading-flag='{{loading}}'><dynamic-show-order></dynamic-show-order></chain-loading-wrapper>",
        controller: "ShowOrderCtrl"
      });
    }
  ]);

}).call(this);

(function() {
  var app;

  app = angular.module('VendorPortal');

  app.controller('ChainVpOrderPanelCtrl', [
    '$scope', '$window', 'chainApiSvc', 'chainDomainerSvc', function($scope, $window, chainApiSvc, chainDomainerSvc) {
      var defaultFields, defaultSorts, initFunc;
      defaultFields = 'ord_ord_num,ord_ord_date,ord_window_start';
      defaultSorts = [
        {
          field: 'ord_window_start'
        }, {
          field: 'ord_ord_num'
        }
      ];
      $scope.getDictionary = function() {
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dictionary = d;
          return d;
        });
      };
      $scope.setActiveOrders = function(searchId, orders) {
        var ref;
        if (searchId === ((ref = $scope.activeSearch) != null ? ref.id : void 0)) {
          $scope.activeOrders = orders;
          return $scope.loading = null;
        }
      };
      $scope.activateOrdersNotApproved = function() {
        var params;
        $scope.loading = 'loading';
        params = {
          fields: defaultFields,
          criteria: [
            {
              field: 'ord_approval_status',
              operator: 'null'
            }
          ],
          sorts: defaultSorts,
          per_page: 50
        };
        return chainApiSvc.Order.search(params).then(function(orders) {
          return $scope.setActiveOrders('notapproved', orders);
        });
      };
      $scope.activateFindOne = function() {
        return $scope.loading = null;
      };
      $scope.activateSearch = function() {
        var so;
        $scope.loading = null;
        so = $.grep($scope.searchOptions, function(el) {
          return el.id === $scope.activeSearch.id;
        });
        if (so.length > 0) {
          $scope.activeOrders = null;
          return $scope[so[0].func]();
        }
      };
      $scope.find = function(orderNumber) {
        var params, trimOrder;
        trimOrder = orderNumber ? $.trim(orderNumber) : '';
        if (trimOrder.length < 3) {
          $window.alert('Please enter at least 3 letters or numbers into search.');
          return;
        }
        params = {
          fields: defaultFields,
          criteria: [
            {
              field: 'ord_ord_num',
              operator: 'co',
              val: trimOrder
            }
          ],
          sorts: defaultSorts,
          per_page: 50
        };
        $scope.activeOrders = null;
        $scope.loading = 'loading';
        return chainApiSvc.Order.search(params).then(function(orders) {
          return $scope.setActiveOrders('findone', orders);
        });
      };
      $scope.searchOptions = [
        {
          id: 'notapproved',
          name: "Not Approved",
          func: 'activateOrdersNotApproved'
        }, {
          id: 'findone',
          name: 'Search',
          func: 'activateFindOne'
        }
      ];
      initFunc = function() {
        $scope.activeSearch = {
          id: 'notapproved'
        };
        $scope.loading = 'loading';
        return $scope.getDictionary().then(function(d) {
          return $scope.activateSearch();
        });
      };
      if (!$scope.$root.isTest) {
        return initFunc();
      }
    }
  ]);

  app.directive('chainVpOrderPanel', function() {
    return {
      restrict: 'E',
      scope: {},
      templateUrl: 'vendor_portal/partials/chain_vp_order_panel.html',
      controller: 'ChainVpOrderPanelCtrl'
    };
  });

}).call(this);

(function() {
  angular.module('VendorPortal').directive('dynamicShowOrder', [
    '$templateRequest', '$compile', function($templateRequest, $compile) {
      return {
        restrict: 'E',
        template: '<div id="dynamic-show-order-wrapper"></div>',
        controller: [
          '$scope', '$element', function($scope, $element) {
            $scope.getTemplate = function() {
              var order, t;
              order = $scope.order;
              if (!(order && order.id && parseInt(order.id) > 0)) {
                return null;
              }
              t = order.custom_view;
              if ((t != null ? t.length : void 0) > 0) {
                return t;
              }
              return '/vendor_portal/partials/standard_order_template.html';
            };
            return $scope.$watch('order.custom_view', function(nv, ov) {
              var newTemplate;
              newTemplate = $scope.getTemplate();
              if (newTemplate && newTemplate !== $scope.activeTemplate) {
                return $templateRequest(newTemplate).then(function(html) {
                  var template;
                  template = angular.element(html);
                  $compile(template)($scope);
                  $element.html(template);
                  return $scope.activeTemplate = newTemplate;
                });
              }
            });
          }
        ]
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').directive('orderAcceptButton', function() {
    return {
      restrict: 'E',
      replace: true,
      template: '<button class="btn btn-xs btn-link" ng-if="order.permissions.can_accept" ng-click="toggleAccept(order)">{{order.ord_approval_status!="Accepted" ? "Accept" : "Clear"}}</button>'
    };
  });

}).call(this);

(function() {
  var app;

  app = angular.module('VendorPortal');

  app.controller('ShowOrderCtrl', [
    '$scope', '$stateParams', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(dict) {
          $scope.dictionary = dict;
          return chainApiSvc.Order.get(id).then(function(order) {
            $scope.order = order;
            return delete $scope.loading;
          });
        });
      };
      $scope.accept = function(order) {
        $scope.loading = 'loading';
        return chainApiSvc.Order.accept(order).then(function(o) {
          $scope.order = o;
          return delete $scope.loading;
        });
      };
      $scope.unaccept = function(order) {
        $scope.loading = 'loading';
        return chainApiSvc.Order.unaccept(order).then(function(o) {
          $scope.order = o;
          return delete $scope.loading;
        });
      };
      $scope.toggleAccept = function(order) {
        if (order.ord_approval_status === 'Accepted') {
          return $scope.unaccept(order);
        } else {
          return $scope.accept(order);
        }
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);
