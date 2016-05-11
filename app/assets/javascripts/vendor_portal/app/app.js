(function() {
  var app;

  app = angular.module('VendorPortal', ['ui.router', 'ChainCommon', 'ChainDomainer', 'VendorPortal-Templates']);

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
        templateUrl: "vendor_portal/partials/main.html"
      }).state('showOrder', {
        url: '/orders/:id',
        template: "<chain-loading-wrapper loading-flag='{{loading}}'><dynamic-show-order></dynamic-show-order></chain-loading-wrapper>",
        controller: "ShowOrderCtrl"
      }).state('selectShipFrom', {
        url: '/orders/:id/select_ship_from',
        templateUrl: "vendor_portal/partials/select_ship_from.html",
        controller: 'SelectShipFromCtrl'
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
      $scope.selectAll = {
        checked: false
      };
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
            }, {
              field: 'ord_closed_at',
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
      $scope.activateOrdersOpen = function() {
        var params;
        $scope.loading = 'loading';
        params = {
          fields: defaultFields,
          criteria: [
            {
              field: 'ord_closed_at',
              operator: 'null'
            }
          ],
          sorts: defaultSorts,
          per_page: 50
        };
        return chainApiSvc.Order.search(params).then(function(orders) {
          return $scope.setActiveOrders('openorders', orders);
        });
      };
      $scope.activateApprovedAndOpen = function() {
        var params;
        $scope.loading = 'loading';
        params = {
          fields: defaultFields,
          criteria: [
            {
              field: 'ord_approval_status',
              operator: 'notnull'
            }, {
              field: 'ord_closed_at',
              operator: 'null'
            }
          ],
          sorts: defaultSorts,
          per_page: 50
        };
        return chainApiSvc.Order.search(params).then(function(orders) {
          return $scope.setActiveOrders('approvedandopen', orders);
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
          id: 'approvedandopen',
          name: 'Approved and Open',
          func: 'activateApprovedAndOpen'
        }, {
          id: 'notapproved',
          name: "Not Approved",
          func: 'activateOrdersNotApproved'
        }, {
          id: 'openorders',
          name: 'Open',
          func: 'activateOrdersOpen'
        }, {
          id: 'findone',
          name: 'Search',
          func: 'activateFindOne'
        }
      ];
      $scope.bulkAccept = function(orders) {
        return chainApiSvc.Bulk.execute(chainApiSvc.Order.accept, orders).then(function() {
          return $scope.activateSearch();
        });
      };
      $scope.bulkComment = function(orders) {
        var comments, i, len, o;
        if (!(orders && orders.length > 0)) {
          return;
        }
        comments = [];
        for (i = 0, len = orders.length; i < len; i++) {
          o = orders[i];
          comments.push({
            commentable_id: o.id,
            commentable_type: 'Order',
            subject: $scope.bulkOrderCommentSubject,
            body: $scope.bulkOrderCommentBody
          });
        }
        return chainApiSvc.Bulk.execute(chainApiSvc.Comment.post, comments).then(function(r) {
          return $scope.activateSearch();
        });
      };
      $scope.selectedOrders = function() {
        if (!$scope.activeOrders) {
          return [];
        }
        return $.grep($scope.activeOrders, function(o) {
          if (o.selected) {
            return o;
          } else {
            return null;
          }
        });
      };
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
        initFunc();
      }
      return $scope.$watch('selectAll.checked', function(nv, ov) {
        var i, j, len, len1, o, ref, ref1, results;
        if (!($scope.activeOrders && $scope.activeOrders.length > 0)) {
          return;
        }
        if (nv) {
          ref = $scope.activeOrders;
          for (i = 0, len = ref.length; i < len; i++) {
            o = ref[i];
            o.selected = true;
          }
        }
        if (!nv && ov) {
          ref1 = $scope.activeOrders;
          results = [];
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            o = ref1[j];
            results.push(delete o.selected);
          }
          return results;
        }
      });
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

angular.module('VendorPortal-Templates', ['vendor_portal/partials/chain_vp_order_panel.html', 'vendor_portal/partials/main.html', 'vendor_portal/partials/select_ship_from.html', 'vendor_portal/partials/standard_order_template.html']);

angular.module("vendor_portal/partials/chain_vp_order_panel.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_order_panel.html",
    "<div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Orders <span class=\"label label-warning\" ng-if=\"loading==&quot;loading&quot;\">Loading</span></h3></div><div class=\"panel-body bg-info\"><select class=\"form-control\" ng-model=\"activeSearch\" ng-change=\"activateSearch()\" ng-options=\"opt.name for opt in searchOptions track by opt.id\"></select></div><div class=\"panel-body form-inline\" ng-if=\"activeSearch.id==&quot;findone&quot;\"><div class=\"form-group\"><input class=\"form-control\" ng-model=\"findOneVal\" placeholder=\"order number\" ng-keyup=\"$event.keyCode == 13 && find(findOneVal)\"> <button class=\"btn btn-success btn-sm\" ng-click=\"find(findOneVal)\"><i class=\"fa fa-search\"></i></button></div></div><div class=\"panel-body\" ng-if=\"loading=='loading'\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper></div><div class=\"panel-body bg-info text-center\" ng-if=\"activeOrders.length == [] && loading!='loading'\"><strong>No orders found</strong></div><div class=\"panel-body bg-danger text-center\" ng-if=\"activeOrders.length > 49 && loading!='loading'\">Only 50 orders are displayed. Use search from the drop down menu to find you order.</div><table class=\"table table-striped\" ng-if=\"activeOrders.length > 0\"><thead><tr><th><input type=\"checkbox\" ng-model=\"selectAll.checked\" title=\"Select All\"></th><th>{{dictionary.fields.ord_ord_num.label}}</th><th>{{dictionary.fields.ord_ord_date.label}}</th><th>{{dictionary.fields.ord_window_start.label}}</th></tr></thead><tr ng-repeat=\"o in activeOrders track by o.id\"><td><input type=\"checkbox\" ng-model=\"o.selected\"></td><td><a ui-sref=\"showOrder({id:o.id})\">{{o.ord_ord_num}}</a></td><td>{{o.ord_ord_date}}</td><td>{{o.ord_window_start}}</td></tr></table><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-primary\" ng-disabled=\"selectedOrders().length==0\" data-toggle=\"modal\" data-target=\"#bulk-comment-selected-orders\" title=\"Add Comments\"><i class=\"fa fa-sticky-note\"></i></button> <button class=\"btn btn-sm btn-primary\" ng-disabled=\"selectedOrders().length==0\" ng-click=\"bulkAccept(selectedOrders())\">Approve</button></div></div><div class=\"modal fade\" id=\"bulk-comment-selected-orders\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Add Comments</h4></div><div class=\"modal-body\"><label for=\"bulkOrderCommentSubject\">Subject</label><input class=\"form-control\" id=\"bulkOrderCommentSubject\" ng-model=\"bulkOrderCommentSubject\"><label for=\"bulkOrderCommentBody\">Body</label><textarea class=\"form-control\" id=\"bulkOrderCommentBody\" ng-model=\"bulkOrderCommentBody\"></textarea><div class=\"alert alert-warning\">This will add comments to {{selectedOrders().length}} orders.</div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-success\" data-dismiss=\"modal\" ng-disabled=\"bulkOrderCommentSubject.length==0 || bulkOrderCommentBody.length==0\" ng-click=\"bulkComment(selectedOrders())\">Send</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/main.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/main.html",
    "<div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><a ui-sref=\"main\"><img src=\"/logo.png\" alt=\"Logo\"></a><br><h1>Vendor Portal</h1></div></div><div class=\"row\"><div class=\"col-md-8\"><chain-vp-order-panel></chain-vp-order-panel></div><div class=\"col-md-4\"><div class=\"panel panel-default\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Surveys</h3></div><div class=\"panel-body text-muted text-center\"><strong>Coming Soon!</strong></div></div><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Settings</h3></div><div class=\"panel-body\"><a href=\"#\" id=\"change-password-link\">Change Password</a></div></div></div></div><chain-change-password-modal></chain-change-password-modal><script>$('#change-password-link').click(function() {\n" +
    "      $('chain-change-password-modal .modal').modal('show');\n" +
    "      return false;\n" +
    "    });</script></div>");
}]);

angular.module("vendor_portal/partials/select_ship_from.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/select_ship_from.html",
    "<div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\"><a ui-sref=\"showOrder({id:order.id})\"><i class=\"fa fa-arrow-left\"></i></a>&nbsp;Select Ship From Address</h3></div><div class=\"panel-body\"><div class=\"row\" ng-repeat=\"ag in addressGroups\"><div class=\"col-md-4\" ng-repeat=\"a in ag track by a.id\"><div class=\"thumbnail\"><iframe ng-src=\"{{a.map_url}}\" style=\"width:100%\"></iframe><div class=\"caption\"><div class=\"text-right text-warning\"><small>Map locations are approximate based on the address text provided.</small></div><div><chain-address address=\"{{a.add_full_address}}\"></chain-address></div><div class=\"text-right\"><button ng-click=\"select(order,a)\" class=\"btn btn-success\" role=\"button\">Select</button></div></div></div></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/standard_order_template.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/standard_order_template.html",
    "<div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><h1><small class=\"text-muted\">Purchase Order</small><br>{{order.ord_ord_num}}</h1></div></div><div class=\"row\"><div class=\"col-md-5\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">&nbsp;</h3></div><div class=\"panel-body\"></div></div></div><div class=\"col-md-7\"></div></div></div>");
}]);

(function() {
  angular.module('VendorPortal').directive('orderAcceptButton', function() {
    return {
      restrict: 'E',
      replace: true,
      template: '<button class="btn btn-xs btn-link" ng-if="order.permissions.can_accept && (order.permissions.can_be_accepted || order.ord_approval_status==\'Accepted\')" ng-click="toggleAccept(order)">{{order.ord_approval_status!="Accepted" ? "Approve" : "Remove"}}</button>'
    };
  });

}).call(this);

(function() {
  angular.module('VendorPortal').controller('SelectShipFromCtrl', [
    '$scope', '$stateParams', '$state', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $state, chainApiSvc, chainDomainerSvc) {
      var addressesInGroups;
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainDomainerSvc.withDictionary().then(function(dict) {
          $scope.dictionary = dict;
          return chainApiSvc.Order.get(id).then(function(order) {
            $scope.order = order;
            return chainApiSvc.Address.search({
              per_page: 50,
              page: 1,
              criteria: [
                {
                  field: 'add_shipping',
                  operator: 'eq',
                  val: 'true'
                }, {
                  field: 'add_comp_syscode',
                  operator: 'eq',
                  val: order.ord_ven_syscode
                }
              ]
            }).then(function(addresses) {
              $scope.addresses = addresses;
              $scope.addressGroups = addressesInGroups(addresses);
              return delete $scope.loading;
            });
          });
        });
      };
      $scope.select = function(order, address) {
        var simplifiedOrderSaveObject;
        $scope.loading = 'loading';
        simplifiedOrderSaveObject = {
          id: order.id,
          ord_ship_from_id: address.id
        };
        chainApiSvc.Order.save(simplifiedOrderSaveObject).then(function(ord) {
          return $state.transitionTo('showOrder', {
            id: ord.id
          });
        });
        return null;
      };
      addressesInGroups = function(addresses) {
        var a, i, innerArray, j, len, r;
        if (!(addresses && addresses.length > 0)) {
          return [];
        }
        r = [];
        innerArray = [];
        for (i = j = 0, len = addresses.length; j < len; i = ++j) {
          a = addresses[i];
          if (i % 4 === 0) {
            r.push(innerArray);
            innerArray = [];
          }
          innerArray.push(a);
        }
        if (innerArray.length !== 0) {
          r.push(innerArray);
        }
        return r;
      };
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

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
          return chainApiSvc.User.me().then(function(me) {
            $scope.me = me;
            return chainApiSvc.Order.get(id).then(function(order) {
              $scope.order = order;
              return delete $scope.loading;
            });
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
