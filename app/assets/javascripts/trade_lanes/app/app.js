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
        templateUrl: 'trade_lanes/partials/index.html'
      }).state('new', {
        url: '/new',
        controller: 'NewCtrl',
        templateUrl: 'trade_lanes/partials/new.html'
      }).state('show', {
        url: '/show/:id',
        controller: 'ShowCtrl',
        templateUrl: 'trade_lanes/partials/show.html'
      }).state('edit', {
        url: '/edit/:id',
        controller: 'EditCtrl',
        templateUrl: 'trade_lanes/partials/edit.html'
      }).state('tpp-show', {
        url: '/tpp/:id',
        controller: 'ShowTppCtrl',
        templateUrl: 'trade_lanes/partials/tpp/show.html'
      }).state('tpp-new', {
        url: '/tpp/new/:origin_iso/:destinatation_iso',
        controller: 'NewTppCtrl',
        templateUrl: 'trade_lanes/partials/tpp/new.html'
      }).state('tpp-edit', {
        url: '/tpp/edit/:id',
        controller: 'EditTppCtrl',
        templateUrl: 'trade_lanes/partials/tpp/edit.html'
      }).state('htso-edit', {
        url: '/htso/edit/:id',
        controller: 'EditHtsoCtrl',
        templateUrl: 'trade_lanes/partials/htso/edit.html'
      }).state('htso-new', {
        url: '/htos/new/:tppid',
        controller: 'NewHtsoCtrl',
        templateUrl: 'trade_lanes/partials/htso/new.html'
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
  angular.module('ChainTradeLanes').controller('EditHtsoCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainApiSvc.TppHtsOverride.get(id).then(function(htso) {
          $scope.htso = htso;
          return chainApiSvc.TradePreferenceProgram.get(htso.tpphtso_trade_preference_program_id).then(function(tpp) {
            $scope.tpp = tpp;
            return chainDomainerSvc.withDictionary().then(function(d) {
              $scope.dict = d;
              return delete $scope.loading;
            });
          });
        });
      };
      $scope.cancel = function(htso) {
        $scope.loading = 'loading';
        return chainApiSvc.TppHtsOverride.load(htso.id).then(function(h) {
          return $state.transitionTo('tpp-show', {
            id: h.tpphtso_trade_preference_program_id
          });
        });
      };
      $scope.save = function(htso) {
        $scope.loading = 'loading';
        return chainApiSvc.TppHtsOverride.save(htso).then(function(h) {
          return $state.transitionTo('tpp-show', {
            id: h.tpphtso_trade_preference_program_id
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
  angular.module('ChainTradeLanes').controller('EditTppCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.TradePreferenceProgram.get(id).then(function(r) {
            $scope.tpp = r;
            return delete $scope.loading;
          });
        });
      };
      $scope.save = function(tpp) {
        $scope.loading = 'loading';
        return chainApiSvc.TradePreferenceProgram.save(tpp).then(function(r) {
          return $state.transitionTo('tpp-show', {
            id: r.id
          });
        });
      };
      $scope.cancel = function(tpp) {
        $scope.loading = 'loading';
        return chainApiSvc.TradePreferenceProgram.load(tpp.id).then(function(r) {
          return $state.transitionTo('tpp-show', {
            id: r.id
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

angular.module('ChainTradeLanes-Templates', ['trade_lanes/partials/edit.html', 'trade_lanes/partials/htso/edit.html', 'trade_lanes/partials/htso/new.html', 'trade_lanes/partials/index.html', 'trade_lanes/partials/new.html', 'trade_lanes/partials/show.html', 'trade_lanes/partials/tpp/edit.html', 'trade_lanes/partials/tpp/new.html', 'trade_lanes/partials/tpp/show.html']);

angular.module("trade_lanes/partials/edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/edit.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>Edit Trade Lane</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_origin_cntry_iso}}\"></chain-flag-icon>{{lane.lane_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_destination_cntry_iso}}\"></chain-flag-icon>{{lane.lane_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"lane\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TradeLane) | chainSkipReadOnly | chainViewFields:['lane_destination_cntry_iso','lane_destination_cntry_name','lane_origin_cntry_iso','lane_origin_cntry_name']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-input model=\"lane\" field=\"fld\" input-class=\"form-control\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(lane)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(lane)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/htso/edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/htso/edit.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>Edit HTS Override</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{tpp.tpp_origin_cntry_iso}}\"></chain-flag-icon>{{tpp.tpp_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{tpp.tpp_destination_cntry_iso}}\"></chain-flag-icon>{{tpp.tpp_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"htso\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TppHtsOverride) | chainSkipReadOnly | chainViewFields:['tpphtso_trade_preference_program_id']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-input model=\"htso\" field=\"fld\" input-class=\"form-control\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(htso)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(htso)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/htso/new.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/htso/new.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>New HTS Override</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{tpp.tpp_origin_cntry_iso}}\"></chain-flag-icon>{{tpp.tpp_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{tpp.tpp_destination_cntry_iso}}\"></chain-flag-icon>{{tpp.tpp_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"htso\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TppHtsOverride) | chainSkipReadOnly | chainViewFields:['tpphtso_trade_preference_program_id']:true track by fld.uid\"><chain-field-label field=\"fld\"></chain-field-label><p class=\"form-control-static\"><chain-field-input model=\"htso\" field=\"fld\" input-class=\"form-control\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(htso)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(htso)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
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
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>Trade Lane</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_origin_cntry_iso}}\"></chain-flag-icon>{{lane.lane_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{lane.lane_destination_cntry_iso}}\"></chain-flag-icon>{{lane.lane_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-6\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"lane\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TradeLane) | chainFieldsWithValues:lane | chainViewFields:['lane_destination_cntry_iso','lane_destination_cntry_name','lane_origin_cntry_iso','lane_origin_cntry_name']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-value model=\"lane\" field=\"fld\"></chain-field-value></p></li></ul><div class=\"panel-footer text-right\" ng-if=\"lane.permissions.can_edit\"><button ng-click=\"edit(lane)\" class=\"btn btn-xs btn-default\"><i class=\"fa fa-edit\"></i></button></div></div><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Preference Programs</h3></div><div class=\"panel-body\" ng-show=\"tppLoading\"><chain-loading-wrapper loading=\"{{tppLoading}}\"></chain-loading-wrapper></div><ul class=\"list-group\"><li class=\"list-group-item\" ng-repeat=\"tpp in tradePrefs track by tpp.id\"><a ui-sref=\"tpp-show({id:tpp.id})\">{{tpp.tpp_name}}</a></li></ul><div class=\"panel-footer text-right\" ng-if=\"lane.permissions.can_edit && me.permissions.edit_trade_preference_programs\"><button class=\"btn btn-sm btn-success\" ui-sref=\"tpp-new({origin_iso:lane.lane_origin_cntry_iso,destinatation_iso:lane.lane_destination_cntry_iso})\"><i class=\"fa fa-plus\"></i></button></div></div></div><div class=\"col-md-6\"><div></div><div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/tpp/edit.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/tpp/edit.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>Edit Trade Preference Program</h1><h3><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{tpp.tpp_origin_cntry_iso}}\"></chain-flag-icon>{{tpp.tpp_origin_cntry_name}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{tpp.tpp_destination_cntry_iso}}\"></chain-flag-icon>{{tpp.tpp_destination_cntry_name}}</h3></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"tpp\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TradePreferenceProgram) | chainSkipReadOnly | chainViewFields:['tpp_destination_cntry_iso','tpp_destination_cntry_name','tpp_origin_cntry_iso','tpp_origin_cntry_name']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-input model=\"tpp\" field=\"fld\" input-class=\"form-control\"></chain-field-input></p></li></ul><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-default\" ng-click=\"cancel(tpp)\">Cancel</button> <button class=\"btn btn-sm btn-success\" ng-click=\"save(tpp)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/tpp/new.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/tpp/new.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-default\"><div class=\"panel-heading\"><h3 class=\"panel-title\">New Trade Preference Program</h3></div><div class=\"panel-body\"><h3 class=\"text-center\"><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{origin_country_iso}}\"></chain-flag-icon>{{origin_country_iso}} <i class=\"fa fa-arrow-right\"></i><chain-flag-icon img-class=\"mini-flag\" iso-code=\"{{destination_country_iso}}\"></chain-flag-icon>{{destination_country_iso}}</h3><label>Name</label><input class=\"form-control\" placeholder=\"Enter program name\" ng-model=\"name\"></div><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-primary\" ng-click=\"create(origin_country_iso,destination_country_iso,name)\" ng-disabled=\"!(name.length > 0)\">Save</button></div></div></div></div></div></chain-loading-wrapper>");
}]);

angular.module("trade_lanes/partials/tpp/show.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("trade_lanes/partials/tpp/show.html",
    "<chain-loading-wrapper loading=\"{{loading}}\"><div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1>{{tpp.tpp_name}}</h1></div></div><div class=\"row\"><div class=\"col-md-6 text-center\"><div><chain-flag-icon iso-code=\"{{tpp.tpp_origin_cntry_iso}}\"></chain-flag-icon></div><div><chain-flag-icon iso-code=\"{{tpp.tpp_destination_cntry_iso}}\"></chain-flag-icon></div></div><div class=\"col-md-6\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attributes</h3></div><ul class=\"list-group\" ng-if=\"tpp\"><li class=\"list-group-item\" ng-repeat=\"fld in dict.fieldsByRecordType(dict.recordTypes.TradePreferenceProgram) | chainFieldsWithValues:tpp | chainViewFields:['tpp_destination_cntry_iso','tpp_destination_cntry_name','tpp_origin_cntry_iso','tpp_origin_cntry_name','tpp_name']:true track by fld.uid\"><label class=\"control-label\">{{fld.label}}</label><p class=\"form-control-static\"><chain-field-value model=\"tpp\" field=\"fld\"></chain-field-value></p></li></ul><div class=\"panel-footer text-right\" ng-if=\"tpp.permissions.can_edit\"><button ng-click=\"edit(tpp)\" class=\"btn btn-xs btn-default\" title=\"Edit Override\"><i class=\"fa fa-edit\"></i></button></div></div></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">HTS Overrides</h3></div><div class=\"panel-body\"><chain-search-table api-object-name=\"TppHtsOverride\" load-trigger=\"overrideSearchSetup.doLoad\" search-setup=\"overrideSearchSetup\"></chain-search-table></div><div class=\"panel-footer text-right\"><button ng-click=\"newOverride(tpp)\" class=\"btn btn-xm btn-success\" title=\"New Override\"><i class=\"fa fa-plus\"></i></button></div></div></div></div></div></chain-loading-wrapper>");
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
  angular.module('ChainTradeLanes').controller('NewHtsoCtrl', [
    '$scope', '$state', '$stateParams', 'chainApiSvc', 'chainDomainerSvc', function($scope, $state, $stateParams, chainApiSvc, chainDomainerSvc) {
      $scope.htso = {};
      $scope.init = function(tppId) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(dict) {
          $scope.dict = dict;
          return chainApiSvc.TradePreferenceProgram.get(tppId).then(function(tpp) {
            $scope.tpp = tpp;
            $scope.htso.tpphtso_trade_preference_program_id = tpp.id;
            return delete $scope.loading;
          });
        });
      };
      $scope.save = function(htso) {
        $scope.loading = 'loading';
        return chainApiSvc.TppHtsOverride.save(htso).then(function(h) {
          return $state.transitionTo('tpp-show', {
            id: h.tpphtso_trade_preference_program_id
          });
        });
      };
      $scope.cancel = function(htso) {
        $scope.loading = 'loading';
        return $state.transitionTo('tpp-show', {
          id: htso.tpphtso_trade_preference_program_id
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.tppid);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainTradeLanes').controller('NewTppCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(originIso, destinationIso) {
        $scope.origin_country_iso = originIso;
        return $scope.destination_country_iso = destinationIso;
      };
      $scope.create = function(originIso, destinationIso, name) {
        var tpp;
        $scope.loading = 'loading';
        tpp = {
          tpp_origin_cntry_iso: originIso,
          tpp_destination_cntry_iso: destinationIso,
          tpp_name: name
        };
        return chainApiSvc.TradePreferenceProgram.save(tpp).then(function(resp) {
          return $state.transitionTo('tpp-show', {
            id: resp.id
          });
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.origin_iso, $stateParams.destinatation_iso);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainTradeLanes').controller('ShowCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        $scope.tppLoading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.User.me().then(function(m) {
            $scope.me = m;
            return chainApiSvc.TradeLane.get(id).then(function(r) {
              var searchOpts;
              $scope.lane = r;
              delete $scope.loading;
              searchOpts = {};
              searchOpts.criteria = [
                {
                  field: 'tpp_origin_cntry_iso',
                  operator: 'eq',
                  val: r.lane_origin_cntry_iso
                }, {
                  field: 'tpp_destination_cntry_iso',
                  operator: 'eq',
                  val: r.lane_destination_cntry_iso
                }
              ];
              searchOpts.sorts = [
                {
                  field: 'tpp_name'
                }
              ];
              return chainApiSvc.TradePreferenceProgram.search(searchOpts).then(function(tpp) {
                $scope.tradePrefs = tpp;
                return delete $scope.tppLoading;
              });
            });
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

(function() {
  angular.module('ChainTradeLanes').controller('ShowTppCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(d) {
          $scope.dict = d;
          return chainApiSvc.TradePreferenceProgram.get(id).then(function(r) {
            $scope.tpp = r;
            $scope.overrideSearchSetup.hiddenCriteria[0].val = r.id;
            $scope.overrideSearchSetup.doLoad = true;
            return delete $scope.loading;
          });
        });
      };
      $scope.edit = function(tpp) {
        $scope.loading = 'loading';
        return $state.transitionTo('tpp-edit', {
          id: tpp.id
        });
      };
      $scope.editOverride = function(override) {
        $scope.loading = 'loading';
        return $state.transitionTo('htso-edit', {
          id: override.id
        });
      };
      $scope.newOverride = function(tpp) {
        $scope.loading = 'loading';
        return $state.transitionTo('htso-new', {
          tppid: tpp.id
        });
      };
      $scope.overrideSearchSetup = {
        doLoad: false,
        hiddenCriteria: [
          {
            operator: 'eq',
            field: 'tpphtso_trade_preference_program_id'
          }
        ],
        columns: ['tpphtso_hts_code', 'tpphtso_rate', 'tpphtso_active', 'tpphtso_note', 'tpphtso_start_date', 'tpphtso_end_date'],
        buttons: [
          {
            label: 'Edit',
            "class": 'btn btn-xs btn-default',
            iconClass: 'fa fa-edit',
            onClick: $scope.editOverride
          }
        ],
        sorts: [
          {
            field: 'tpphtso_hts_code'
          }
        ]
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);
