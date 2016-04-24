(function() {
  var app;

  app = angular.module('ChainTradeLanes', ['ui.router', 'ChainCommon', 'ChainDomainer', 'ChainTradeLanes-Templates']);

  app.config([
    '$httpProvider', function($httpProvider) {
      return $httpProvider.defaults.headers.common['Accept'] = 'application/json';
    }
  ]);

  app.config([
    '$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $urlRouterProvider.otherwise('/');
      return $stateProvider.state('index', {
        url: '/',
        controller: 'IndexCtrl',
        templateUrl: "trade_lanes/partials/index.html"
      }).state('new', {
        url: '/new',
        controller: 'NewCtrl',
        templateUrl: "trade_lanes/partials/new.html"
      }).state('show', {
        url: '/show/:id',
        controller: 'ShowCtrl',
        templateUrl: "trade_lanes/partials/show.html"
      }).state('edit', {
        url: '/edit/:id',
        controller: 'EditCtrl',
        templateUrl: "trade_lanes/partials/edit.html"
      });
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').controller('EditCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.TradeLane.get(id).then(function(r) {
            $scope.lane = r;
            return delete $scope.loading;
          });
        });
      };
      $scope.save = function(lane) {
        $scope.loading = 'loading';
        return chainApiSvc.TradeLane.save(lane).then(function(resp) {
          return $state.transitionTo('show', {
            id: resp.id
          });
        });
      };
      $scope.cancel = function(lane) {
        $scope.loading = 'loading';
        return chainApiSvc.TradeLane.load(lane.id).then(function(resp) {
          return $state.transitionTo('show', {
            id: resp.id
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
  angular.module('ChainTradeLanes').controller('IndexCtrl', [
    '$scope', 'chainApiSvc', function($scope, chainApiSvc) {
      var loadPage;
      loadPage = function(pageNumber) {
        return chainApiSvc.TradeLane.search({
          per_page: 50,
          page: pageNumber,
          oid1: 'lane_origin_cntry_name',
          oid2: 'lane_destination_cntry_name'
        }).then(function(found) {
          $scope.lanes = $scope.lanes.concat(found);
          if (found.length >= 50) {
            loadPage(pageNumber + 1);
          }
          return delete $scope.loading;
        });
      };
      $scope.init = function() {
        $scope.loading = 'loading';
        $scope.lanes = [];
        return loadPage(1);
      };
      if (!$scope.$root.isTest) {
        return $scope.init();
      }
    }
  ]);

}).call(this);

angular.module('ChainTradeLanes-Templates', ['trade_lanes/partials/edit.html', 'trade_lanes/partials/index.html', 'trade_lanes/partials/new.html', 'trade_lanes/partials/show.html']);

angular.module("trade_lanes/partials/edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/edit.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>Edit Trade Lane</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_origin_cntry_iso}}\"></chain-flag-icon>{{lane.lane_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_destination_cntry_iso}}\"></chain-flag-icon>{{lane.lane_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"lane\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TradeLane) | chainSkipReadOnly | chainViewFields:['lane_destination_cntry_iso','lane_destination_cntry_name','lane_origin_cntry_iso','lane_origin_cntry_name']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-input model=\"lane\" field=\"fld\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(lane)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(lane)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/index.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/index.html",
    "<div class=\"container\"><div class=\"row\"><h1 class=\"text-center\">Trade Lanes</h1><table class=\"table table-striped\"><thead><tr><th></th><th>Origin</th><th>Destination</th></tr></thead><tbody><tr ng-repeat=\"lane in lanes track by lane.id\"><td><button type=\"button\" class=\"btn btn-sm btn-primary\" ui-sref=\"show({id:lane.id})\">View</button></td><td><chain-flag-icon iso-code=\"{{lane.lane_origin_cntry_iso}}\" img-class=\"index-flag\"></chain-flag-icon>{{lane.lane_origin_cntry_name}}</td><td><chain-flag-icon iso-code=\"{{lane.lane_destination_cntry_iso}}\" img-class=\"index-flag\"></chain-flag-icon>{{lane.lane_destination_cntry_name}}</td></tr><tr ng-if=\"loading==&quot;loading&quot;\"><td class=\"text-center\" colspan=\"3\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper></td></tr></tbody></table></div></div>");
}]);

angular.module("trade_lanes/partials/new.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/new.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">New Trade Lane</h3></div><div class=\"panel-body\"><label for=\"origin-country\">Origin</label><select class=\"form-control\" id=\"origin-country\" ng-model=\"vals.origin\" ng-options=\"c as c.name for c in countries track by c.id\"></select><label for=\"destination-country\">Destination</label><select class=\"form-control\" id=\"destination-country\" ng-model=\"vals.destination\" ng-options=\"c as c.name for c in countries track by c.id\"></select></div><div class=\"panel-footer text-right\">&nbsp; <span ng-if=\"existingLane\">Trade Lane already exists. <a ui-sref=\"show({id:existingLane.id})\">Click here to view.</a></span> <button ng-click=\"create(vals.origin,vals.destination)\" class=\"btn btn-success\" ng-show=\"isShowCreate()\">Create</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/show.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/show.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>Trade Lane</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_origin_cntry_iso}}\"></chain-flag-icon>{{lane.lane_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_destination_cntry_iso}}\"></chain-flag-icon>{{lane.lane_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-6\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"lane\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TradeLane) | chainFieldsWithValues:lane | chainViewFields:['lane_destination_cntry_iso','lane_destination_cntry_name','lane_origin_cntry_iso','lane_origin_cntry_name']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-value model=\"lane\" field=\"fld\"></chain-field-value></p></li></ul><div class=\"panel-footer text-right\"><button ng-click=\"edit(lane)\" class=\"btn btn-xs btn-default\"><i class=\"fa fa-edit\"></i></button></div></div><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Preference Programs</h3></div><div class=\"panel-body\"></div><div class=\"panel-footer\"></div></div></div><div class=\"col-md-6\"><div></div><div></div></div></div></div></chain-loading-wrapper>");
}]);

(function() {
  var app;

  app = angular.module('ChainTradeLanes').controller('NewCtrl', [
    '$scope', '$state', 'chainApiSvc', function($scope, $state, chainApiSvc) {
      var validateMe;
      $scope.vals = {
        origin: null,
        destination: null
      };
      $scope.init = function() {
        $scope.loading = 'loading';
        return chainApiSvc.Country.list().then(function(c) {
          $scope.countries = c;
          return delete $scope.loading;
        });
      };
      $scope.create = function(origin, dest) {
        $scope.loading = 'loading';
        return chainApiSvc.TradeLane.save({
          lane_origin_cntry_iso: origin.iso_code,
          lane_destination_cntry_iso: dest.iso_code
        }).then(function(resp) {
          return $state.transitionTo('show', {
            id: resp.id
          });
        });
      };
      $scope.isShowCreate = function() {
        return $scope.vals.origin && $scope.vals.destination && !$scope.checkingLaneExists && !$scope.existingLane;
      };
      $scope.alreadyExistsCheck = function(origin, dest) {
        $scope.checkingLaneExists = true;
        $scope.existingLane = null;
        return chainApiSvc.TradeLane.search({
          criteria: [
            {
              field: 'lane_origin_cntry_iso',
              operator: 'eq',
              val: origin.iso_code
            }, {
              field: 'lane_destination_cntry_iso',
              operator: 'eq',
              val: dest.iso_code
            }
          ]
        }).then(function(results) {
          delete $scope.checkingLaneExists;
          return $scope.existingLane = results[0];
        });
      };
      validateMe = function(nv, ov) {
        if ($scope.vals.origin && $scope.vals.destination) {
          return $scope.alreadyExistsCheck($scope.vals.origin, $scope.vals.destination);
        }
      };
      if (!$scope.$root.isTest) {
        $scope.init();
      }
      $scope.$watch('vals.origin', validateMe);
      return $scope.$watch('vals.destination', validateMe);
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainTradeLanes').controller('ShowCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.TradeLane.get(id).then(function(r) {
            $scope.lane = r;
            return delete $scope.loading;
          });
        });
      };
      $scope.edit = function(lane) {
        $scope.loading = 'loading';
        return $state.transitionTo('edit', {
          id: lane.id
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);
