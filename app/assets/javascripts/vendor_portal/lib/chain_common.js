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
      return publicMethods;
    }
  ]);

}).call(this);
