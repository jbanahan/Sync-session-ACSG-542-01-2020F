(function() {
  var app;

  app = angular.module('VendorPortal', ['ui.router', 'ChainCommon']);

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
        templateUrl: "/vendor_portal/partials/main.html",
        controller: [
          '$scope', '$state', 'chainApiSvc', function($scope, $state, chainApiSvc) {
            var params;
            params = {
              fields: 'ord_ord_num,ord_ord_date',
              criteria: [
                {
                  field: 'ord_approval_status',
                  operator: 'notnull'
                }
              ]
            };
            chainApiSvc.Order.search(params).then(function(orders) {
              return $scope.orders = orders;
            });
            return $scope.world = 'Earth';
          }
        ]
      });
    }
  ]);

}).call(this);
