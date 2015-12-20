(function() {
  var app;

  app = angular.module('ChainCommon', ['ChainCommon-Templates']);

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
    '$http', '$q', '$sce', function($http, $q, $sce) {
      var newCoreModuleClient, newMessageClient, newUserClient, publicMethods;
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
      newMessageClient = function() {
        var processMessageResponse;
        processMessageResponse = function(m) {
          if (m.body) {
            m.htmlSafeBody = $sce.trustAsHtml(m.body);
          }
          return m;
        };
        return {
          list: function(pageNumber) {
            var pn;
            pn = pageNumber ? pageNumber : 1;
            return $http.get('/api/v1/messages.json?page=' + pn).then(function(resp) {
              var j, len, m, msgs;
              msgs = resp.data.messages;
              for (j = 0, len = msgs.length; j < len; j++) {
                m = msgs[j];
                processMessageResponse(m);
              }
              return msgs;
            });
          },
          count: function(user) {
            return $http.get('/api/v1/messages/count/' + user.id + '.json').then(function(resp) {
              return resp.data.message_count;
            });
          },
          markAsRead: function(message) {
            return $http.post('/api/v1/messages/' + message.id + '/mark_as_read.json', {
              message: message
            }).then(function(resp) {
              return processMessageResponse(resp.data.message);
            });
          }
        };
      };
      publicMethods.Message = newMessageClient();
      newUserClient = function() {
        var cachedMe;
        cachedMe = null;
        return {
          loadMe: function() {
            return $http.get('/api/v1/users/me.json').then(function(resp) {
              return resp.data.user;
            });
          },
          me: function() {
            var d;
            if (cachedMe) {
              d = $q.defer();
              d.resolve(cachedMe);
              return d.promise;
            } else {
              return this.loadMe().then(function(u) {
                cachedMe = u;
                return cachedMe;
              });
            }
          },
          toggleEmailNewMessages: function() {
            return $http.post('/api/v1/users/me/toggle_email_new_messages.json', {}).then(function(resp) {
              cachedMe = resp.data.user;
              return cachedMe;
            });
          }
        };
      };
      publicMethods.User = newUserClient();
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
  var app;

  app = angular.module('ChainCommon');

  app.directive('chainMessagesLink', [
    'chainApiSvc', '$interval', '$timeout', '$compile', function(chainApiSvc, $interval, $timeout, $compile) {
      return {
        restrict: 'E',
        scope: {},
        replace: true,
        template: "<a ng-click='showModal()'>Messages</a>",
        link: function(scope, el, attrs) {
          var actuallyShowModal, updateMessageCount;
          updateMessageCount = function() {
            return chainApiSvc.User.me().then(function(me) {
              return chainApiSvc.Message.count(me).then(function(c) {
                if (c > 0) {
                  return el.html('Messages (' + c + ')');
                } else {
                  return el.html('Messages');
                }
              });
            });
          };
          updateMessageCount();
          $interval(updateMessageCount, 30000);
          actuallyShowModal = function() {
            return $('#chain-messages-modal').modal('show');
          };
          return scope.showModal = function() {
            var compiledEl, mod;
            mod = $('#chain-messages-modal');
            if (mod.length === 0) {
              compiledEl = angular.element('<chain-messages-modal></chain-messages-modal>');
              $compile(compiledEl)(scope.$root.$new());
              $('body').append(compiledEl);
              $timeout(actuallyShowModal, 0);
            } else {
              actuallyShowModal();
            }
            return null;
          };
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainMessagesModal', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {},
        templateUrl: 'chain-messages-modal.html',
        link: function(scope, el, atrs) {
          scope.loadMessages = function() {
            delete scope.messages;
            return chainApiSvc.Message.list().then(function(msgs) {
              scope.messages = msgs;
              return scope.messages;
            });
          };
          scope.loadUser = function() {
            delete scope.user;
            return chainApiSvc.User.me().then(function(u) {
              scope.user = u;
              return scope.user;
            });
          };
          scope.readMessage = function(message) {
            if (!message.viewed) {
              chainApiSvc.Message.markAsRead(message);
            }
            message.shown = true;
            return message.viewed = true;
          };
          scope.toggleEmailNewMessages = function() {
            scope.loading = 'loading';
            return chainApiSvc.User.toggleEmailNewMessages().then(function(u) {
              scope.user = u;
              return delete scope.loading;
            });
          };
          return $(el).on('show.bs.modal', function() {
            scope.loading = 'loading';
            return scope.loadUser().then(function() {
              return scope.loadMessages().then(function() {
                return delete scope.loading;
              });
            });
          });
        }
      };
    }
  ]);

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

angular.module('ChainCommon-Templates', ['chain-messages-modal.html']);

angular.module("chain-messages-modal.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-messages-modal.html",
    "<div class=\"modal\" id=\"chain-messages-modal\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Messages</h4></div><div class=\"modal-body\"><chain-loading-wrapper loading-flag=\"{{loading}}\"><div ng-if=\"messages && messages.length==0\" class=\"text-success text-center\">You don't have any messages.</div><div class=\"panel-group\"><div class=\"panel\" ng-repeat=\"m in messages track by m.id\"><div class=\"panel-heading\"><h3 class=\"panel-title subject\" ng-click=\"readMessage(m)\" ng-class=\"{'unread-subject':!m.viewed}\">{{m.subject}}</h3></div><div ng-show=\"m.shown\" class=\"panel-body\"><div ng-bind-html=\"m.htmlSafeBody\" class=\"message-body\"></div></div></div></div></chain-loading-wrapper></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" id=\"toggle-email-new-messages\" ng-click=\"toggleEmailNewMessages()\"><i class=\"fa\" ng-class=\"{'fa-square-o':!user.email_new_messages, 'fa-check-square-o':user.email_new_messages}\"></i> Email Messages</button> <button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button></div></div></div></div>");
}]);
