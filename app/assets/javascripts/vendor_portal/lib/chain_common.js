(function() {
  var app;

  app = angular.module('ChainCommon', []);

  app.config([
    '$httpProvider', function($httpProvider) {
      return $httpProvider.defaults.headers.common['Accept'] = 'application/json';
    }
  ]);

}).call(this);

(function() {
  var app;

  app = angular.module('ChainCommon');

  app.factory('chainApiSvc', [
    '$http', '$q', function($http, $q) {
      var newCoreModuleClient, publicMethods;
      publicMethods = {};
      newCoreModuleClient = function(moduleType, objectProperty, loadSuccessHandler) {
        var cache, handleServerResponse, sanitizeSearchCriteria, sanitizeSortOpts, setCache;
        cache = {};
        handleServerResponse = function(resp) {
          var data;
          data = resp.data[objectProperty];
          if (loadSuccessHandler) {
            return loadSuccessHandler(data);
          } else {
            return data;
          }
        };
        setCache = function(obj) {
          cache[obj.id] = obj;
          return obj;
        };
        sanitizeSortOpts = function(opts) {
          var i, j, len, ref, s;
          if (opts.sorts) {
            ref = opts.sorts;
            for (i = j = 0, len = ref.length; j < len; i = ++j) {
              s = ref[i];
              opts['oid' + i] = s.field;
              if (s.order) {
                opts['oo' + i] = s.order;
              }
            }
            return delete opts.sorts;
          }
        };
        sanitizeSearchCriteria = function(opts) {
          var c, i, j, len, ref;
          if (opts.criteria) {
            ref = opts.criteria;
            for (i = j = 0, len = ref.length; j < len; i = ++j) {
              c = ref[i];
              opts['sid' + i] = c.field;
              opts['sop' + i] = c.operator;
              opts['sv' + i] = c.val;
            }
            return delete opts.criteria;
          }
        };
        return {
          get: function(id, queryOpts) {
            var deferred;
            if (cache[id]) {
              deferred = $q.defer();
              deferred.resolve(cache[id]);
              return deferred.promise;
            } else {
              return this.load(id, queryOpts);
            }
          },
          load: function(id, queryOpts) {
            var config;
            config = {};
            if (queryOpts) {
              config.params = queryOpts;
            }
            return $http.get('/api/v1/' + moduleType + '/' + id + '.json', config).then(handleServerResponse).then(setCache);
          },
          save: function(obj, extraOpts) {
            var data, method, url;
            data = $.extend({}, extraOpts);
            data[objectProperty] = obj;
            method = 'post';
            url = '/api/v1/' + moduleType;
            if (obj.id && obj.id > 0) {
              method = 'put';
              url = url + "/" + obj.id;
            }
            return $http[method](url + '.json', data).then(handleServerResponse).then(setCache);
          },
          search: function(searchOpts) {
            var sOpts;
            sOpts = $.extend({}, searchOpts);
            sanitizeSortOpts(sOpts);
            sanitizeSearchCriteria(sOpts);
            return $http.get('/api/v1/' + moduleType + '.json', {
              params: sOpts
            }).then(function(resp) {
              var j, len, r, ref, v;
              r = [];
              ref = resp.data.results;
              for (j = 0, len = ref.length; j < len; j++) {
                v = ref[j];
                if (loadSuccessHandler) {
                  r.push(loadSuccessHandler(v));
                } else {
                  r.push(v);
                }
              }
              return r;
            });
          }
        };
      };
      publicMethods.Product = newCoreModuleClient('products', 'product', function(product) {
        delete product.prod_ent_type_id;
        return product;
      });
      publicMethods.Order = newCoreModuleClient('orders', 'order');
      publicMethods.Order.accept = function(order) {
        return $http.post('/api/v1/orders/' + order.id + '/accept.json', {
          id: order.id
        }).then(function(resp) {
          return publicMethods.Order.load(order.id);
        });
      };
      publicMethods.Order.unaccept = function(order) {
        return $http.post('/api/v1/orders/' + order.id + '/unaccept.json', {
          id: order.id
        }).then(function(resp) {
          return publicMethods.Order.load(order.id);
        });
      };
      return publicMethods;
    }
  ]);

}).call(this);

(function() {
  var cDom;

  cDom = angular.module('ChainDomainer', ['Domainer']);

  cDom.factory('chainDomainerSvc', [
    '$http', 'domainerSvc', function($http, domainerSvc) {
      var domainDAOChain, setupDone;
      domainDAOChain = {
        makeDictionary: function(worker) {
          return $http.get('/api/v1/model_fields').then(function(resp) {
            var data, dict, fld, i, j, len, len1, recordTypes, ref, ref1, rt;
            data = resp.data;
            dict = new DomainDictionary();
            recordTypes = {};
            ref = data.recordTypes;
            for (i = 0, len = ref.length; i < len; i++) {
              rt = ref[i];
              dict.registerRecordType(rt);
              recordTypes[rt.uid] = rt;
            }
            ref1 = data.fields;
            for (j = 0, len1 = ref1.length; j < len1; j++) {
              fld = ref1[j];
              fld.recordType = recordTypes[fld.record_type_uid];
              dict.registerField(fld);
            }
            return worker(dict);
          });
        }
      };
      setupDone = false;
      return {
        withDictionary: function() {
          if (!setupDone) {
            domainerSvc.setLocalDAO(domainDAOChain);
            domainerSvc.setRemoteDAO(domainDAOChain);
            domainerSvc.setExpirationChecker(new DomainExpirationCheckerLocal());
            setupDone = true;
          }
          return domainerSvc.withDictionary();
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainLoader', function() {
    return {
      restrict: 'E',
      replace: true,
      template: '<div class="chain-loader"></div>'
    };
  });

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainLoadingWrapper', function() {
    return {
      restrict: 'E',
      scope: {
        loadingFlag: '@'
      },
      transclude: true,
      template: "<div class='container-fluid' ng-if='isLoading()'> <div class='row'> <div class='col-md-12'> <chain-loader></chain-loader> </div> </div> </div> <div ng-transclude ng-if='!isLoading()'></div>",
      link: function(scope, el, attrs) {
        return scope.isLoading = function() {
          return scope.loadingFlag === 'loading';
        };
      }
    };
  });

}).call(this);

(function() {
  var dMod;

  dMod = angular.module('Domainer', []);

  dMod.factory('domainerSvc', [
    '$q', function($q) {
      var domainer, expChecker, localDAO, remoteDAO;
      localDAO = null;
      remoteDAO = null;
      expChecker = null;
      domainer = null;
      return {
        setLocalDAO: function(d) {
          localDAO = d;
          return domainer = null;
        },
        setRemoteDAO: function(d) {
          remoteDAO = d;
          return domainer = null;
        },
        setExpirationChecker: function(d) {
          expChecker = d;
          return domainer = null;
        },
        withDictionary: function() {
          var deferred;
          if (!domainer) {
            domainer = new Domainer(new DomainDataAccessSetup(localDAO, remoteDAO, expChecker));
          }
          deferred = $q.defer();
          domainer.withDictionary(function(dict) {
            return deferred.resolve(dict);
          });
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);
