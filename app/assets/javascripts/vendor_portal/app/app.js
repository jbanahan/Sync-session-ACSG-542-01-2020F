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
      }).state('selectTppSurveyResponse', {
        url: '/orders/:id/select_tpp_survey_response',
        templateUrl: "vendor_portal/partials/select_tpp_survey_response.html",
        controller: 'SelectTppSurveyResponseCtrl'
      }).state('showShipment', {
        url: '/shipments/:id',
        template: "<chain-loading-wrapper loading-flag='{{loading}}'><dynamic-show-shipment></dynamic-show-shipment></chain-loading-wrapper>",
        controller: "ShowShipmentCtrl"
      });
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').directive('chainVpBookOrder', [
    '$state', 'chainApiSvc', 'chainDomainerSvc', function($state, chainApiSvc, chainDomainerSvc) {
      return {
        restrict: 'E',
        scope: {
          order: '='
        },
        templateUrl: 'vendor_portal/partials/chain_vp_book_order.html',
        link: function(scope, el, attrs) {
          var loadModal;
          loadModal = function() {
            scope.loading = 'loading';
            return chainDomainerSvc.withDictionary().then(function(dict) {
              scope.dict = dict;
              return chainApiSvc.Shipment.search({
                columns: ['shp_booked_orders', 'shp_ref'],
                criteria: [
                  {
                    field: 'shp_shipment_instructions_sent_date',
                    operator: 'null'
                  }, {
                    field: 'shp_ven_id',
                    operator: 'eq',
                    val: scope.order.ord_ven_id
                  }, {
                    field: 'shp_imp_id',
                    operator: 'eq',
                    val: scope.order.ord_imp_id
                  }
                ]
              }).then(function(shipments) {
                scope.shipments = shipments;
                return delete scope.loading;
              });
            });
          };
          scope.showModal = function() {
            loadModal();
            $(el).find('.modal').modal('show');
            return null;
          };
          scope.addToShipment = function(shp) {
            scope.loading = 'loading';
            return chainApiSvc.Shipment.bookOrder(shp, scope.order).then(function(resp) {
              $(el).on('hidden.bs.modal', function() {
                return $state.transitionTo('showShipment', {
                  id: shp.id
                });
              });
              $(el).find('.modal').modal('hide');
              return null;
            });
          };
          return scope.addToNewShipment = function() {
            scope.loading = 'loading';
            return chainApiSvc.Shipment.bookOrderToNewShipment(scope.order).then(function(resp) {
              $(el).on('hidden.bs.modal', function() {
                return $state.transitionTo('showShipment', {
                  id: resp.id
                });
              });
              $(el).find('.modal').modal('hide');
              return null;
            });
          };
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').directive('chainVpBookings', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          order: '='
        },
        templateUrl: 'vendor_portal/partials/chain_vp_bookings.html',
        link: function(scope, el, attrs) {
          var init;
          init = function() {
            var searchSetup;
            scope.loading = 'loading';
            searchSetup = {
              columns: ['shp_booked_orders', 'shp_ref'],
              criteria: [
                {
                  field: 'shp_booked_order_ids',
                  operator: 'co',
                  val: scope.order.id
                }
              ]
            };
            return chainApiSvc.Shipment.search(searchSetup).then(function(shipments) {
              scope.shipments = shipments;
              return delete scope.loading;
            });
          };
          scope.$watch('order.id', function(nv, ov) {
            if (nv > 0) {
              return init();
            }
          });
          if (scope.order && scope.order.id > 0) {
            return init();
          }
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').directive('chainVpEquipmentRequestor', function() {
    return {
      restrict: 'E',
      scope: {
        shipment: '=',
        okCallback: '=',
        equipmentTypes: '='
      },
      templateUrl: 'vendor_portal/partials/chain_vp_equipment_requestor.html',
      link: function(scope, el, attrs) {
        var parseExistingValue, writeReqVal;
        scope.numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20];
        scope.requestedEquipment = {};
        writeReqVal = function(rEquip, row) {
          var elements;
          elements = row.split(' ');
          if (elements.length !== 2) {
            return;
          }
          return rEquip[elements[1]] = elements[0];
        };
        parseExistingValue = function(shp) {
          var i, len, rEquip, reqRows, reqStr, row;
          rEquip = {};
          reqStr = shp.shp_requested_equipment;
          if (reqStr && reqStr.length > 0) {
            reqRows = reqStr.split("\n");
            for (i = 0, len = reqRows.length; i < len; i++) {
              row = reqRows[i];
              writeReqVal(rEquip, row);
            }
          }
          return rEquip;
        };
        scope.showModal = function() {
          scope.requestedEquipment = parseExistingValue(scope.shipment);
          el.find('.modal').modal('show');
          return null;
        };
        return scope.commitChange = function() {
          var num, t, val;
          val = [];
          for (t in scope.requestedEquipment) {
            num = scope.requestedEquipment[t];
            if (num && num > 0) {
              val.push(num + " " + t);
            }
          }
          scope.shipment.shp_requested_equipment = val.join("\n");
          el.on('hidden.bs.modal', function() {
            if (scope.okCallback) {
              return scope.okCallback(scope.shipment);
            }
          });
          el.find('.modal').modal('hide');
          return null;
        };
      }
    };
  });

}).call(this);

(function() {
  angular.module('VendorPortal').directive('chainVpFullShipmentPack', [
    '$window', 'chainApiSvc', function($window, chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          shipment: '=',
          dictionary: '='
        },
        templateUrl: 'vendor_portal/partials/chain_vp_full_shipment_pack.html',
        link: function(scope, el, attrs) {
          var cleanContainerNumber, getQuantity, matchingContainer, setUnshippedLines;
          cleanContainerNumber = function(baseContainer) {
            var baseCN;
            baseCN = baseContainer.con_container_number;
            if (!baseCN) {
              baseCN = '';
            }
            baseCN = baseCN.trim().toUpperCase();
            return baseCN;
          };
          matchingContainer = function(baseContainer, collection) {
            var c, c1, i, len;
            c1 = cleanContainerNumber(baseContainer);
            if (collection) {
              for (i = 0, len = collection.length; i < len; i++) {
                c = collection[i];
                if (cleanContainerNumber(c) === c1) {
                  return c;
                }
              }
            }
            return null;
          };
          setUnshippedLines = function(shp) {
            var bl, i, j, k, len, len1, len2, ol, ref, ref1, ref2, results, shippedOrderLineIds, sl;
            scope.unShippedBookingLines = [];
            shippedOrderLineIds = [];
            if (shp.lines) {
              ref = shp.lines;
              for (i = 0, len = ref.length; i < len; i++) {
                sl = ref[i];
                ref1 = sl.order_lines;
                for (j = 0, len1 = ref1.length; j < len1; j++) {
                  ol = ref1[j];
                  shippedOrderLineIds.push(ol.id);
                }
              }
            }
            if (shp.booking_lines) {
              ref2 = shp.booking_lines;
              results = [];
              for (k = 0, len2 = ref2.length; k < len2; k++) {
                bl = ref2[k];
                if (!(shippedOrderLineIds.indexOf(bl.bkln_order_line_id) >= 0)) {
                  results.push(scope.unShippedBookingLines.push(bl));
                } else {
                  results.push(void 0);
                }
              }
              return results;
            }
          };
          scope.bookingTableFields = ['bkln_line_number', 'bkln_order_and_line_number', 'bkln_puid', 'bkln_quantity'];
          scope.containerTableFields = ['con_container_number', 'con_container_size'];
          scope.shipmentLineTableFields = ['shpln_line_number', 'shpln_puid', 'shpln_shipped_qty'];
          scope.containerToAdd = {};
          scope.showModal = function(shp) {
            setUnshippedLines(shp);
            el.find('.modal').modal('show');
            return null;
          };
          scope.addContainer = function(shp, con) {
            var cleanCN, shpToSave;
            scope.addingContainer = true;
            if (matchingContainer(con, shp.containers)) {
              cleanCN = cleanContainerNumber(con);
              $window.alert("Container " + cleanCN + " is already on this shipment.");
              return delete scope.addingContainer;
            } else {
              shpToSave = {
                id: shp.id,
                containers: [con]
              };
              return chainApiSvc.Shipment.save(shpToSave).then(function(savedShp) {
                var mc;
                if (!shp.containers) {
                  shp.containers = [];
                }
                mc = matchingContainer(con, savedShp.containers);
                if (mc) {
                  shp.containers.push(mc);
                }
                scope.containerToAdd = {};
                return delete scope.addingContainer;
              });
            }
          };
          scope.shouldDisableAddContainer = function() {
            var cta;
            if (scope.addingContainer) {
              return true;
            }
            cta = scope.containerToAdd;
            if (!(cta.con_container_number && cta.con_container_number.length > 0 && cta.con_container_size)) {
              return true;
            }
            return false;
          };
          scope.packLines = function(shp, con) {
            var bl, i, len, ref;
            if (!con) {
              return;
            }
            if (!shp.booking_lines) {
              return;
            }
            if (!shp.lines) {
              shp.lines = [];
            }
            ref = shp.booking_lines;
            for (i = 0, len = ref.length; i < len; i++) {
              bl = ref[i];
              if (bl.readyForPack) {
                delete bl.readyForPack;
                shp.lines.push({
                  shpln_line_number: bl.bkln_line_number,
                  linked_order_line_id: bl.bkln_order_line_id,
                  shpln_shipped_qty: bl.bkln_quantity,
                  shpln_container_number: con.con_container_number,
                  shpln_puid: bl.bkln_puid,
                  order_lines: [
                    {
                      id: bl.bkln_order_line_id
                    }
                  ]
                });
              }
            }
            return setUnshippedLines(shp);
          };
          getQuantity = function(collection, attribute) {
            return collection.reduce((function(pv, obj) {
              var val;
              val = obj[attribute];
              if (val === void 0 || val === '') {
                val = 0;
              }
              return pv + val;
            }), 0);
          };
          scope.canSave = function(shp) {
            if (scope.isSaving) {
              return false;
            }
            if (!(shp.booking_lines && shp.lines && shp.booking_lines.length === shp.lines.length)) {
              return false;
            }
            if (getQuantity(shp.booking_lines, 'bkln_quantity') !== getQuantity(shp.lines, 'shpln_shipped_qty')) {
              return false;
            }
            return true;
          };
          scope.save = function(shp) {
            var con, i, len, ref;
            scope.isSaving = true;
            ref = shp.containers;
            for (i = 0, len = ref.length; i < len; i++) {
              con = ref[i];
              if (scope.linesForContainer(shp, con).length === 0) {
                con._destroy = true;
              }
            }
            chainApiSvc.Shipment.save(shp).then(function(saved) {
              var modal;
              modal = el.find('.modal');
              modal.on('hidden.bs.modal', function() {
                return scope.$emit('chain-shipment-save', saved);
              });
              return modal.modal('hide');
            });
            return null;
          };
          scope.cancel = function(shp) {
            var i, len, newSl, ref, sl;
            newSl = [];
            ref = shp.lines;
            for (i = 0, len = ref.length; i < len; i++) {
              sl = ref[i];
              if (sl.id && sl.id > 0) {
                newSl.push(sl);
              }
            }
            shp.lines = newSl;
            el.find('.modal').modal('hide');
            return null;
          };
          scope.linesForContainer = function(shp, container) {
            if (!shp.lines) {
              return [];
            }
            return $.grep(shp.lines, function(sl) {
              return sl.shpln_container_number === container.con_container_number;
            });
          };
          scope.$on('chain-shipment-loaded', function() {
            return setUnshippedLines(scope.shipment);
          });
          if (scope.shipment && scope.shipment.id) {
            return setUnshippedLines(scope.shipment);
          }
        }
      };
    }
  ]);

}).call(this);

(function() {
  var app;

  app = angular.module('VendorPortal');

  app.controller('ChainVpOrderPanelCtrl', [
    '$scope', '$state', '$window', 'chainApiSvc', 'chainDomainerSvc', 'bulkSelectionSvc', function($scope, $state, $window, chainApiSvc, chainDomainerSvc, bulkSelectionSvc) {
      $scope.pageUid = 'chain-vp-order-panel';
      $scope.baseSearch = function() {
        var ss;
        return ss = {
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
      $scope.showOrder = function(ord, $event) {
        var url;
        if ($event.ctrlKey) {
          url = $state.href('showOrder', {
            id: ord.id
          });
          $window.open(url, '_blank');
        } else {
          $state.transitionTo('showOrder', {
            id: ord.id
          });
        }
        return null;
      };
      $scope.bulkApprove = function() {
        var orders;
        orders = bulkSelectionSvc.selected($scope.pageUid);
        if (orders && orders.length > 0) {
          return chainApiSvc.Bulk.execute(chainApiSvc.Order.accept, orders);
        }
      };
      return $scope.hasSelections = function() {
        return bulkSelectionSvc.selectedCount($scope.pageUid) > 0;
      };
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
  var app;

  app = angular.module('VendorPortal');

  app.controller('ChainVpShipmentPanelCtrl', [
    '$scope', '$state', '$window', 'chainApiSvc', 'chainDomainerSvc', 'bulkSelectionSvc', function($scope, $state, $window, chainApiSvc, chainDomainerSvc, bulkSelectionSvc) {
      var activateSearchWithCriteria, initFunc;
      $scope.pageUid = 'chain-vp-shipment-panel';
      $scope.showShipment = function(shp) {
        return $state.transitionTo('showShipment', {
          id: shp.id
        });
      };
      $scope.coreSearch = {};
      $scope.selectAll = {
        checked: false
      };
      activateSearchWithCriteria = function(hiddenCriteria) {
        return $scope.coreSearch.searchSetup = {
          reload: new Date().getTime(),
          hiddenCriteria: hiddenCriteria,
          columns: ['shp_ref', 'shp_booking_received_date', 'shp_booking_confirmed_date', 'shp_departure_date'],
          buttons: [
            {
              label: 'View',
              "class": 'btn btn-xs btn-default',
              iconClass: 'fa fa-eye',
              onClick: $scope.showShipment
            }
          ],
          sorts: [
            {
              field: 'shp_booking_received_date'
            }, {
              field: 'shp_ref'
            }
          ],
          bulkSelections: {}
        };
      };
      $scope.activateShipmentsNotBooked = function() {
        return activateSearchWithCriteria([
          {
            field: 'shp_booking_received_date',
            operator: 'null'
          }
        ]);
      };
      $scope.activateShipmentsNotConfirmed = function() {
        return activateSearchWithCriteria([
          {
            field: 'shp_booking_received_date',
            operator: 'notnull'
          }, {
            field: 'shp_booking_confirmed_date',
            operator: 'null'
          }
        ]);
      };
      $scope.activateShipmentsNotShipped = function() {
        return activateSearchWithCriteria([
          {
            field: 'shp_booking_received_date',
            operator: 'notnull'
          }, {
            field: 'shp_booking_confirmed_date',
            operator: 'notnull'
          }, {
            field: 'shp_departure_date',
            operator: 'null'
          }
        ]);
      };
      $scope.activateShipmentsShipped = function() {
        return activateSearchWithCriteria([
          {
            field: 'shp_departure_date',
            operator: 'notnull'
          }
        ]);
      };
      $scope.activateFindOne = function() {
        return null;
      };
      $scope.activateSearch = function() {
        var so;
        so = $.grep($scope.searchOptions, function(el) {
          return el.id === $scope.activeSearch.id;
        });
        if (so.length > 0) {
          return $scope[so[0].func]();
        }
      };
      $scope.find = function(shipmentNumber) {
        var defaultFields, defaultSorts, trimVal;
        defaultFields = 'shp_ref,shp_booking_received_date,shp_booking_confirmed_date,shp_departure_date';
        defaultSorts = [
          {
            field: 'shp_booking_received_date'
          }, {
            field: 'shp_ref'
          }
        ];
        trimVal = shipmentNumber ? $.trim(shipmentNumber) : '';
        if (trimVal.length < 3) {
          $window.alert('Please enter at least 3 letters or numbers into search.');
          return;
        }
        return activateSearchWithCriteria([
          {
            field: 'shp_ref',
            operator: 'co',
            val: trimVal
          }
        ]);
      };
      $scope.searchOptions = [
        {
          id: 'notbooked',
          name: 'Not Booked',
          func: 'activateShipmentsNotBooked'
        }, {
          id: 'notconfirmed',
          name: 'Booked - Not Confirmed',
          func: 'activateShipmentsNotConfirmed'
        }, {
          id: 'notshipped',
          name: 'Booked - Not Shipped',
          func: 'activateShipmentsNotShipped'
        }, {
          id: 'shipped',
          name: 'Shipped',
          func: 'activateShipmentsShipped'
        }, {
          id: 'findone',
          name: 'Search',
          func: 'activateFindOne'
        }
      ];
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
            commentable_type: 'Shipment',
            subject: $scope.bulkShipmentCommentSubject,
            body: $scope.bulkShipmentCommentBody
          });
        }
        return chainApiSvc.Bulk.execute(chainApiSvc.Comment.post, comments).then(function(r) {
          return $scope.activateSearch();
        });
      };
      $scope.selectedShipments = function() {
        return bulkSelectionSvc.selected($scope.pageUid);
      };
      $scope.selectionCount = function() {
        return bulkSelectionSvc.selectedCount($scope.pageUid);
      };
      $scope.selectNone = function() {
        return bulkSelectionSvc.selectNone($scope.pageUid);
      };
      $scope.hasSelectedShipments = function() {
        return $scope.selectionCount() > 0;
      };
      initFunc = function() {
        $scope.activeSearch = {
          id: 'notbooked'
        };
        return $scope.activateSearch();
      };
      if (!$scope.$root.isTest) {
        return initFunc();
      }
    }
  ]);

  app.directive('chainVpShipmentPanel', function() {
    return {
      restrict: 'E',
      scope: {},
      templateUrl: 'vendor_portal/partials/chain_vp_shipment_panel.html',
      controller: 'ChainVpShipmentPanelCtrl'
    };
  });

}).call(this);

(function() {
  angular.module('VendorPortal').directive('chainVpVariantSelector', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          canEdit: '=',
          orderLine: '=',
          vendorId: '=',
          dictionary: '='
        },
        templateUrl: 'vendor_portal/partials/chain_vp_variant_selector.html',
        link: function(scope, el, attrs) {
          scope.activateModal = function() {
            scope.loading = 'loading';
            chainApiSvc.Variant.forVendorProduct(scope.vendorId, scope.orderLine.ordln_prod_db_id).then(function(variants) {
              scope.variants = variants;
              return delete scope.loading;
            });
            el.find('.modal').modal('show');
            return null;
          };
          scope.selectVariant = function(v) {
            return scope.selectedVariant = v;
          };
          return scope.save = function() {
            var ol, simplifiedOrder;
            scope.loading = 'loading';
            if (!scope.selectedVariant) {
              return;
            }
            ol = scope.orderLine;
            simplifiedOrder = {
              id: ol.order_id,
              order_lines: [
                {
                  id: ol.id,
                  ordln_var_db_id: scope.selectedVariant.id
                }
              ]
            };
            return chainApiSvc.Order.save(simplifiedOrder).then(function(resp) {
              var modal;
              delete scope.loading;
              modal = el.find('.modal');
              modal.on('hidden.bs.modal', function() {
                return scope.$emit('chain-order-save', resp);
              });
              modal.modal('hide');
              return null;
            });
          };
        }
      };
    }
  ]);

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
              return 'vendor_portal/partials/standard_order_template.html';
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
  angular.module('VendorPortal').directive('dynamicShowShipment', [
    '$templateRequest', '$compile', function($templateRequest, $compile) {
      return {
        restrict: 'E',
        template: '<div id="dynamic-show-shipment-wrapper"></div>',
        controller: [
          '$scope', '$element', function($scope, $element) {
            $scope.getTemplate = function() {
              var shipment, t;
              shipment = $scope.shipment;
              if (!(shipment && shipment.id && parseInt(shipment.id) > 0)) {
                return null;
              }
              t = shipment.custom_view;
              if ((t != null ? t.length : void 0) > 0) {
                return t;
              }
              return 'vendor_portal/partials/standard_shipment_template.html';
            };
            return $scope.$watch('shipment.custom_view', function(nv, ov) {
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

angular.module('VendorPortal-Templates', ['vendor_portal/partials/chain_vp_book_order.html', 'vendor_portal/partials/chain_vp_bookings.html', 'vendor_portal/partials/chain_vp_equipment_requestor.html', 'vendor_portal/partials/chain_vp_full_shipment_pack.html', 'vendor_portal/partials/chain_vp_order_panel.html', 'vendor_portal/partials/chain_vp_shipment_panel.html', 'vendor_portal/partials/chain_vp_variant_selector.html', 'vendor_portal/partials/main.html', 'vendor_portal/partials/order_accept_button.html', 'vendor_portal/partials/select_ship_from.html', 'vendor_portal/partials/select_tpp_survey_response.html', 'vendor_portal/partials/standard_order_template.html', 'vendor_portal/partials/standard_shipment_template.html']);

angular.module("vendor_portal/partials/chain_vp_book_order.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_book_order.html",
    "<button class=\"btn btn-sm btn-primary\" ng-if=\"order.permissions.can_book\" ng-click=\"showModal()\">Book Order</button><div class=\"modal fade text-left\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Select Shipment</h4></div><div class=\"modal-body\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><table class=\"table\" ng-hide=\"loading\"><thead><tr><th>{{dict.field('shp_ref').label}}</th><th>{{dict.field('shp_booked_orders').label}}</th><th>&nbsp;</th></tr></thead><tbody><tr ng-repeat=\"s in shipments track by s.id\"><td><chain-field-value model=\"s\" field=\"dict.field(&quot;shp_ref&quot;)\"></chain-field-value></td><td><chain-field-value model=\"s\" field=\"dict.field(&quot;shp_booked_orders&quot;)\"></chain-field-value></td><td><button class=\"btn btn-sm btn-success\" title=\"Add to shipment\" ng-click=\"addToShipment(s)\"><i class=\"fa fa-plus\"></i></button></td></tr><tr><td colspan=\"3\"><button class=\"btn btn-success\" title=\"Add to NEW shipment\" ng-click=\"addToNewShipment()\">Create New Shipment</button></td></tr></tbody></table></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_bookings.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_bookings.html",
    "<small ng-if=\"loading\">Loading bookings</small><chain-vp-book-order order=\"order\" ng-if=\"shipments.length==0\"></chain-vp-book-order><span ng-repeat=\"s in shipments track by s.id\"><a ui-sref=\"showShipment(s)\">{{s.shp_ref}}</a><span ng-if=\"!$last\">,</span></span>");
}]);

angular.module("vendor_portal/partials/chain_vp_equipment_requestor.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_equipment_requestor.html",
    "<pre>\n" +
    "{{shipment.shp_requested_equipment}}\n" +
    "</pre><button class=\"btn btn-sm btn-primary\" ng-show=\"shipment.permissions.can_edit\" ng-click=\"showModal()\">Change</button><div class=\"modal fade\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Equipment Request</h4></div><div class=\"modal-body\"><div class=\"form-group\" ng-repeat=\"et in equipmentTypes track by $index\"><label>{{et}}</label><select class=\"form-control\" ng-options=\"n for n in numbers track by n\" ng-model=\"requestedEquipment[et]\"></select></div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Cancel</button> <button type=\"button\" class=\"btn btn-primary\" ng-click=\"commitChange()\">OK</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_full_shipment_pack.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_full_shipment_pack.html",
    "<button ng-click=\"showModal(shipment)\" ng-disabled=\"!shipment.permissions.can_add_remove_shipment_lines || shipment.shp_shipment_instructions_sent_date || unShippedBookingLines.length == 0\" class=\"btn btn-default\">Pack Manifest</button><div class=\"modal fade\" data-backdrop=\"static\" data-keyboard=\"false\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\" data-backdrop=\"static\" data-keyboard=\"false\"><div class=\"modal-dialog\"><div class=\"modal-content text-left\"><div class=\"modal-header\"><h4 class=\"modal-title\">Pack Shipment</h4></div><div class=\"modal-body\"><h4>Available Booking Lines</h4><div class=\"alert alert-success\" ng-show=\"unShippedBookingLines.length>0\">All lines must be packed to save shipment.</div><table class=\"table available-lines\"><thead><tr><th></th><th ng-repeat=\"uid in bookingTableFields track by $index\">{{dictionary.field(uid).label}}</th></tr></thead><tbody><tr ng-repeat=\"bl in unShippedBookingLines track by bl.id\"><td><input type=\"checkbox\" ng-model=\"bl.readyForPack\"></td><td ng-repeat=\"uid in bookingTableFields track by $index\">{{bl[uid]}}</td></tr></tbody></table><div class=\"text-right\"><label>Container</label><select class=\"form-control\" ng-model=\"containerToPack\" ng-options=\"con.con_container_number for con in shipment.containers\"></select><button class=\"btn btn-default\" ng-click=\"packLines(shipment,containerToPack)\">Pack Lines</button></div><h4>Containers</h4><table class=\"table containers\"><thead><tr><th ng-repeat=\"uid in containerTableFields track by $index\">{{dictionary.field(uid).label}}</th><th><button class=\"btn btn-sm btn-success\" ng-show=\"!showAddContainer\" ng-click=\"showAddContainer = true\" title=\"Show Add Container\"><i class=\"fa fa-plus\"></i></button> <button class=\"btn btn-sm btn-success\" ng-show=\"showAddContainer\" ng-click=\"showAddContainer = false\" title=\"Hide Add Container\"><i class=\"fa fa-minus\"></i></button></th></tr></thead><tbody><tr class=\"add-container-row\" ng-show=\"showAddContainer\"><td ng-repeat=\"uid in containerTableFields track by $index\"><chain-field-input model=\"containerToAdd\" field=\"dictionary.field(uid)\"></chain-field-input></td><td><button class=\"btn btn-xm btn-success\" ng-disabled=\"shouldDisableAddContainer()\" title=\"Add Container\" ng-click=\"addContainer(shipment,containerToAdd)\"><i class=\"fa fa-plus\"></i></button></td></tr></tbody><tbody ng-repeat=\"con in shipment.containers track by con.id\"><tr class=\"info\"><td ng-repeat=\"uid in containerTableFields track by $index\"><chain-field-value model=\"con\" field=\"dictionary.field(uid)\"></chain-field-value></td><td></td></tr><tr><td colspan=\"{{containerTableFields.length + 1}}\"><table class=\"table\" ng-show=\"linesForContainer(shipment,con).length > 0\"><thead><tr><td ng-repeat=\"uid in shipmentLineTableFields track by $index\">{{dictionary.field(uid).label}}</td></tr></thead><tbody><tr ng-repeat=\"ln in linesForContainer(shipment,con)\"><td ng-repeat=\"uid in shipmentLineTableFields track by $index\"><chain-field-value model=\"ln\" field=\"dictionary.field(uid)\"></chain-field-value></td></tr></tbody></table><div class=\"text-warning\" ng-show=\"linesForContainer(shipment,con).length == 0\">Empty containers will be removed when you save.</div></td></tr></tbody></table></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" ng-click=\"cancel(shipment)\">Cancel</button> <button type=\"button\" class=\"btn btn-primary\" ng-disabled=\"!canSave(shipment)\" ng-click=\"save(shipment)\">Save</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_order_panel.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_order_panel.html",
    "<chain-search-panel name=\"Orders\" api-object-name=\"Order\" base-search-setup-function=\"baseSearch\" page-uid=\"{{pageUid}}\" bulk-edit=\"true\"><chain-bulk-edit api-object-name=\"Order\" page-uid=\"{{pageUid}}\" button-classes=\"btn-sm btn-default\"></chain-bulk-edit><chain-bulk-comment api-object-name=\"Order\" page-uid=\"{{pageUid}}\" button-classes=\"btn-sm btn-default\"></chain-bulk-comment><button class=\"btn btn-sm btn-default\" ng-click=\"bulkApprove()\" ng-disabled=\"!hasSelections()\">Approve</button></chain-search-panel>");
}]);

angular.module("vendor_portal/partials/chain_vp_shipment_panel.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_shipment_panel.html",
    "<div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Shipments</h3></div><div class=\"panel-body bg-info\"><select class=\"form-control\" ng-model=\"activeSearch\" ng-change=\"activateSearch()\" ng-options=\"opt.name for opt in searchOptions track by opt.id\"></select></div><div class=\"panel-body form-inline\" ng-if=\"activeSearch.id==&quot;findone&quot;\"><div class=\"form-group\"><input class=\"form-control\" ng-model=\"findOneVal\" placeholder=\"order number\" ng-keyup=\"$event.keyCode == 13 && find(findOneVal)\"> <button class=\"btn btn-success btn-sm\" ng-click=\"find(findOneVal)\"><i class=\"fa fa-search\"></i></button></div></div><div class=\"panel-body\"><chain-search-table api-object-name=\"Shipment\" search-setup=\"coreSearch.searchSetup\" page-uid=\"{{pageUid}}\"></chain-search-table></div><div class=\"panel-footer text-right\"><button class=\"btn btn-sm btn-primary\" ng-click=\"selectNone()\">Clear Selection ({{selectionCount()}})</button> <button class=\"btn btn-sm btn-primary\" ng-disabled=\"!hasSelectedShipments()\" data-toggle=\"modal\" data-target=\"#bulk-comment-selected-shipments\" title=\"Add Comments\"><i class=\"fa fa-sticky-note\"></i></button></div></div><div class=\"modal fade\" id=\"bulk-comment-selected-shipments\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Add Comments</h4></div><div class=\"modal-body\"><label for=\"bulkShipmentCommentSubject\">Subject</label><input class=\"form-control\" id=\"bulkShipmentCommentSubject\" ng-model=\"bulkShipmentCommentSubject\"><label for=\"bulkShipmentCommentBody\">Body</label><textarea class=\"form-control\" id=\"bulkShipmentCommentBody\" ng-model=\"bulkShipmentCommentBody\"></textarea><div class=\"alert alert-warning\">This will add comments to {{selectedOrders().length}} orders.</div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-success\" data-dismiss=\"modal\" ng-disabled=\"bulkShipmentCommentSubject.length==0 || bulkShipmentCommentBody.length==0\" ng-click=\"bulkComment(selectedShipments())\">Send</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_variant_selector.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_variant_selector.html",
    "<span>{{orderLine.ordln_varuid}}</span> <button class=\"btn btn-xs btn-default\" ng-if=\"canEdit\" title=\"Change Variant\" ng-click=\"activateModal()\"><i class=\"fa fa-edit\"></i></button><div class=\"modal fade\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Change Variant</h4></div><div class=\"modal-body\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><div class=\"panel\" ng-repeat=\"v in variants track by v.id\" ng-class=\"{'panel-primary':v==selectedVariant,'panel-default':v!=selectedVariant}\"><div class=\"panel-heading\"><h3 class=\"panel-title\">{{v.var_identifier}}</h3></div><div class=\"panel-body\"><pre>\n" +
    "{{v[dictionary.fieldsByAttribute('label','Recipe',dictionary.fieldsByRecordType(dictionary.recordTypes.Variant))[0].uid]}}\n" +
    "</pre></div><div class=\"panel-footer text-right\"><button class=\"btn btn-primary btn-sm\" title=\"Select Variant\" ng-click=\"selectVariant(v)\">Select</button></div></div><div ng-show=\"variants && variants.length==0 && !loading\" class=\"text-danger\">No variants are assigned to this product.</div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button> <button type=\"button\" class=\"btn btn-success\" ng-disabled=\"!selectedVariant || loading\" ng-click=\"save()\">Save</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/main.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/main.html",
    "<div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><a ui-sref=\"main\"><img src=\"/logo.png\" alt=\"Logo\"></a><br><h1>Vendor Portal</h1></div></div><div class=\"row\"><div class=\"col-md-8\"><chain-vp-order-panel></chain-vp-order-panel></div><div class=\"col-md-4\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Settings</h3></div><div class=\"panel-body\"><a href=\"#\" id=\"change-password-link\">Change Password</a></div></div></div></div><chain-change-password-modal></chain-change-password-modal><script>$('#change-password-link').click(function() {\n" +
    "      $('chain-change-password-modal .modal').modal('show');\n" +
    "      return false;\n" +
    "    });</script></div>");
}]);

angular.module("vendor_portal/partials/order_accept_button.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/order_accept_button.html",
    "<button class=\"btn btn-xs {{order.ord_approval_status!=&quot;Accepted&quot; ? &quot;btn-success&quot; : &quot;btn-link&quot;}}\" ng-if=\"order.permissions.can_accept && (order.permissions.can_be_accepted || order.ord_approval_status=='Accepted')\" ng-click=\"toggleAccept(order)\"><span ng-show=\"order.ord_approval_status!='Accepted'\">Approve</span> <span ng-show=\"order.ord_approval_status=='Accepted'\" class=\"fa fa-trash text-danger\" title=\"Remove\"></span></button>");
}]);

angular.module("vendor_portal/partials/select_ship_from.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/select_ship_from.html",
    "<div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\"><a ui-sref=\"showOrder({id:order.id})\"><i class=\"fa fa-arrow-left\"></i></a>&nbsp;Select Ship From Address</h3></div><div class=\"panel-body\"><div class=\"row\" ng-repeat=\"ag in addressGroups\"><div class=\"col-md-4\" ng-repeat=\"a in ag track by a.id\"><div class=\"thumbnail\"><iframe ng-src=\"{{a.map_url}}\" style=\"width:100%\"></iframe><div class=\"caption\"><div class=\"text-right text-warning\"><small>Map locations are approximate based on the address text provided.</small></div><div><chain-address address=\"{{a.add_full_address}}\"></chain-address></div><div class=\"text-right\"><button ng-click=\"select(order,a)\" class=\"btn btn-success\" role=\"button\">Select</button></div></div></div></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/select_tpp_survey_response.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/select_tpp_survey_response.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><div class=\"panel panel-primary\" ng-show=\"loading!=&quot;loading&quot;\"><div class=\"panel-heading\"><h3 class=\"panel-title\"><a ui-sref=\"showOrder(order.id)\"><i class=\"fa fa-arrow-left\"></i></a>&nbsp;Select Trade Preference Program Certification</h3></div><div class=\"panel-body\"><select class=\"form-control\" title=\"Select TPP Certification\" ng-model=\"tppSurveyResponse\" ng-options=\"a.long_name for a in availableResponses\"></select></div><div class=\"panel-footer text-right\"><button class=\"btn btn-default\" ng-click=\"showOrder(order.id)\">Cancel</button> <button class=\"btn btn-primary\" ng-click=\"select(order)\">Select</button></div></div>");
}]);

angular.module("vendor_portal/partials/standard_order_template.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/standard_order_template.html",
    "<div class=\"container\" id=\"standard-order-template\"><div class=\"row\"><div class=\"col-md-12 text-center\"><a ui-sref=\"main\"><img src=\"/logo.png\" alt=\"Logo\"></a><br><h1><small>Purchase Order</small><br>{{order.ord_ord_num}}</h1></div></div><div class=\"row\"><div class=\"col-md-5\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"></div><ul class=\"list-group\"><li class=\"list-group-item\">Issue Date <span class=\"pull-right\">{{order.ord_ord_date}}</span></li><li class=\"list-group-item\" ng-if=\"order.ord_window_start && order.ord_window_start==order.ord_window_end\">Delivery Date <span class=\"pull-right\">{{order.ord_window_start}}</span></li><li class=\"list-group-item\" ng-if=\"order.ord_window_start && order.ord_window_start!=order.ord_window_end\">Ship Window Start <span class=\"pull-right\">{{order.ord_window_start}}</span></li><li class=\"list-group-item\" ng-if=\"order.ord_window_end && order.ord_window_start!=order.ord_window_end\">Ship Window End <span class=\"pull-right\">{{order.ord_window_end}}</span></li><li class=\"list-group-item\">Vendor No. <span class=\"pull-right\">{{order.ord_ven_syscode}}</span></li><li class=\"list-group-item\">Vendor Name <span class=\"pull-right\">{{order.ord_ven_name}}</span></li><li class=\"list-group-item\">Currency <span class=\"pull-right\">{{order.ord_currency}}</span></li><li class=\"list-group-item\">Terms of Payment <span class=\"pull-right\">{{order.ord_payment_terms}}</span></li><li class=\"list-group-item\">Terms of Delivery <span class=\"pull-right\">{{order.ord_terms}}</span></li><li class=\"list-group-item\">Delivery Location <span class=\"pull-right\">{{order.ord_fob_point}}</span></li></ul></div><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Order Status</h3></div><ul class=\"list-group\"><li class=\"list-group-item\">Vendor Approval <span class=\"pull-right\">{{order.ord_approval_status}} <a class=\"label label-default\" ng-if=\"!order.permissions.can_be_accepted && order.ord_approval_status!=&quot;Accepted&quot;\" data-toggle=\"modal\" data-target=\"#mod_cant_be_accepted\">Not Ready</a><order-accept-button></order-accept-button></span></li></ul></div></div><div class=\"col-md-7\"><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Vendor Order Address</h3></div><div class=\"panel-body\"><chain-address address=\"{{order.ord_order_from_address_full_address}}\"></chain-address></div></div><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Ship From Address</h3></div><div class=\"panel-body\"><div class=\"text-warning\" ng-show=\"order.permissions.can_edit && order.vendor_id == me.company_id && !order.ord_ship_from_full_address.length>0\">Please select a ship from address using the Change button below.</div><chain-address address=\"{{order.ord_ship_from_full_address}}\"></chain-address></div><div class=\"panel-footer text-right\" ng-if=\"order.permissions.can_edit && order.vendor_id == me.company_id\"><a ui-sref=\"selectShipFrom({id:order.id})\" class=\"btn btn-primary\">Change</a></div></div><div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Ship To Address</h3></div><div ng-if=\"order.order_lines.length > 0 && order.ord_ship_to_count==1\" class=\"panel-body\"><chain-address address=\"{{order.order_lines[0].ordln_ship_to_full_address}}\"></chain-address></div><div ng-if=\"order.ord_ship_to_count > 1\" class=\"panel-body\"><strong>Multi-Stop</strong></div></div><div class=\"panel panel-primary\" ng-if=\"order.available_tpp_survey_responses.length > 0\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Trade Preference Program Certification</h3></div><div class=\"panel-body\">{{order.ord_tppsr_name}}<div ng-if=\"!order.ord_tppsr_db_id\" class=\"alert alert-info\">No trade preference program selected.</div></div><div class=\"panel-footer text-right\"><button class=\"btn btn-primary\" ui-sref=\"selectTppSurveyResponse({id:order.id})\">Change</button></div></div></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"panel panel-primary\"><table class=\"table table-bordered table-striped\"><thead><tr><th>Line Num</th><th>Article</th><th ng-if=\"order.ord_ship_to_count > 1\">Ship To</th><th>Quantity</th><th>UM</th><th>Unit Price</th><th>Net Amount</th></tr></thead><tbody><tr ng-repeat=\"ol in order.order_lines track by ol.id\"><td>{{ol.ordln_line_number}}</td><td><small>{{ol.ordln_puid}}</small><br>{{ol.ordln_pname}}</td><td ng-if=\"order.ord_ship_to_count > 1\"><chain-address address=\"{{ol.ordln_ship_to_full_address}}\"></chain-address></td><td class=\"text-right numeric\">{{ol.ordln_ordered_qty}}</td><td>{{ol.ordln_unit_of_measure}}</td><td class=\"text-right numeric\">{{ol.ordln_ppu}}</td><td class=\"text-right numeric\">{{ol.ordln_total_cost}}</td></tr><tr><td class=\"text-right\" colspan=\"5\">Total</td><td class=\"text-right numeric\">{{order.ord_total_cost}}</td></tr></tbody></table></div></div></div><div class=\"row\"><div class=\"col-md-6\"><chain-comments-panel parent=\"order\" module-type=\"Order\"></chain-comments-panel></div><div class=\"col-md-6\"><chain-attachments-panel parent=\"order\" module-type=\"Order\"></chain-attachments-panel></div></div></div><div class=\"modal fade\" id=\"mod_cant_be_accepted\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Pending Updates</h4></div><div class=\"modal-body\">This order is does not have all data elements completed and cannot be accepted.</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/standard_shipment_template.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("vendor_portal/partials/standard_shipment_template.html",
    "<div id=\"standard-shipment-template\"><h1>Shipment {{shipment.shp_ref}}</h1></div>");
}]);

(function() {
  angular.module('VendorPortal').directive('orderAcceptButton', function() {
    return {
      restrict: 'E',
      replace: true,
      templateUrl: 'vendor_portal/partials/order_accept_button.html'
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
  angular.module('VendorPortal').controller('SelectTppSurveyResponseCtrl', [
    '$scope', '$state', '$stateParams', 'chainApiSvc', function($scope, $state, $stateParams, chainApiSvc) {
      var initResponses;
      initResponses = function(order) {
        var a, ar, dbId, i, len, results;
        ar = order.available_tpp_survey_responses;
        if (!ar) {
          ar = [];
        }
        ar.unshift({
          id: null,
          long_name: '[none]'
        });
        $scope.availableResponses = ar;
        if (order.ord_tppsr_db_id) {
          dbId = order.ord_tppsr_db_id;
          results = [];
          for (i = 0, len = ar.length; i < len; i++) {
            a = ar[i];
            if (a.id === dbId) {
              results.push($scope.tppSurveyResponse = a);
            } else {
              results.push(void 0);
            }
          }
          return results;
        }
      };
      $scope.init = function(id) {
        $scope.loading = 'loading';
        return chainApiSvc.Order.get(id).then(function(ord) {
          initResponses(ord);
          $scope.order = ord;
          return delete $scope.loading;
        });
      };
      $scope.showOrder = function(id) {
        $scope.loading = 'loading';
        return chainApiSvc.Order.get(id).then(function(ord) {
          return $state.transitionTo('showOrder', {
            id: ord.id
          });
        });
      };
      $scope.select = function(ord) {
        var val;
        $scope.loading = 'loading';
        val = null;
        if ($scope.tppSurveyResponse) {
          val = $scope.tppSurveyResponse.id;
        }
        ord.ord_tppsr_db_id = val;
        return chainApiSvc.Order.save(ord).then(function(ord) {
          return $state.transitionTo('showOrder', {
            id: ord.id
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
      $scope.save = function(order) {
        $scope.loading = 'loading';
        return chainApiSvc.Order.save(order).then(function(o) {
          $scope.order = o;
          return delete $scope.loading;
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
      $scope.reload = function() {
        $scope.loading = 'loading';
        return chainApiSvc.Order.load($scope.order.id).then(function(order) {
          $scope.order = order;
          return delete $scope.loading;
        });
      };
      $scope.$on('chain-order-save', function(evt, ord) {
        return $scope.reload();
      });
      if (!$scope.$root.isTest) {
        return $scope.init($stateParams.id);
      }
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').controller('ShowShipmentCtrl', [
    '$scope', '$stateParams', '$window', '$q', 'chainApiSvc', 'chainDomainerSvc', function($scope, $stateParams, $window, $q, chainApiSvc, chainDomainerSvc) {
      var saveAndAct;
      $scope.init = function(id) {
        $scope.loading = 'loading';
        chainDomainerSvc.withDictionary().then(function(dict) {
          return $scope.dictionary = dict;
        });
        return chainApiSvc.User.me().then(function(me) {
          $scope.me = me;
          return chainApiSvc.Shipment.get(id).then(function(shipment) {
            $scope.shipment = shipment;
            $scope.$broadcast('chain-shipment-loaded', shipment);
            return delete $scope.loading;
          });
        });
      };
      $scope.reload = function(id) {
        $scope.loading = 'loading';
        return chainApiSvc.Shipment.load(id).then(function(s) {
          $scope.shipment = s;
          $scope.$broadcast('chain-shipment-loaded', s);
          return delete $scope.loading;
        });
      };
      $scope.save = function(shp) {
        $scope.loading = 'loading';
        return chainApiSvc.Shipment.save(shp).then(function(s) {
          return $scope.reload(shp.id);
        });
      };
      saveAndAct = function(shp, permission, failMessage, actionFunction) {
        if (!permission) {
          $window.alert(failMessage);
          return;
        }
        $scope.loading = 'loading';
        return chainApiSvc.Shipment.save(shp).then(function(respShp) {
          return actionFunction(respShp).then(function(resp) {
            return $scope.reload(shp.id);
          });
        });
      };
      $scope.requestBooking = function(shp) {
        return saveAndAct(shp, shp.permissions.can_request_booking, "You do not have permission to request bookings.", chainApiSvc.Shipment.requestBooking);
      };
      $scope.reviseBooking = function(shp) {
        return saveAndAct(shp, shp.permissions.can_revise_booking, "You do not have permission to revise bookings.", chainApiSvc.Shipment.reviseBooking);
      };
      $scope.requestCancel = function(shp) {
        if ($window.confirm("Are you sure you want to cancel this shipment? You'll need to start over.")) {
          return saveAndAct(shp, shp.permissions.can_request_cancel, "You do not have permission to cancel this shipment.", chainApiSvc.Shipment.requestCancel);
        }
      };
      $scope.uncancel = function(shp) {
        return saveAndAct(shp, shp.permissions.can_uncancel, "You do not have permission to undo canceling this shipment.", chainApiSvc.Shipment.uncancel);
      };
      $scope.sendShipmentInstructions = function(shp) {
        return saveAndAct(shp, shp.permissions.can_send_shipment_instructions, "You do not have permission to send shipment instructions for this shipment.", chainApiSvc.Shipment.sendShipmentInstructions);
      };
      $scope.unBookOrder = function(bookingLine) {
        var bl, delShip, i, len, linesToDelete;
        linesToDelete = $.grep($scope.shipment.booking_lines, function(bl) {
          return bl.bkln_order_id === bookingLine.bkln_order_id;
        });
        if ($window.confirm("Are you sure you want to remove " + linesToDelete.length + " lines from this booking?")) {
          $scope.loading = 'loading';
          delShip = {
            id: $scope.shipment.id,
            booking_lines: []
          };
          for (i = 0, len = linesToDelete.length; i < len; i++) {
            bl = linesToDelete[i];
            delShip.booking_lines.push({
              id: bl.id,
              _destroy: true
            });
          }
          return chainApiSvc.Shipment.save(delShip).then(function(s) {
            return $scope.reload(delShip.id);
          });
        }
      };
      $scope.clearManifest = function(shp) {
        var c, i, j, len, len1, ln, nullFunc, ref, ref1, shpToSave;
        if ($window.confirm("Are you sure you want to clear the manfiest and start over?")) {
          nullFunc = function(shp) {
            var d;
            d = $q.defer();
            d.resolve(shp);
            return d.promise;
          };
          shpToSave = {
            id: shp.id,
            lines: [],
            containers: []
          };
          ref = shp.lines;
          for (i = 0, len = ref.length; i < len; i++) {
            ln = ref[i];
            shpToSave.lines.push({
              id: ln.id,
              _destroy: true
            });
          }
          ref1 = shp.containers;
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            c = ref1[j];
            shpToSave.containers.push({
              id: c.id,
              _destroy: true
            });
          }
          return saveAndAct(shpToSave, shp.permissions.can_add_remove_shipment_lines, "You do not have permission to remove lines from this shipment.", nullFunc);
        }
      };
      if (!$scope.$root.isTest) {
        $scope.init($stateParams.id);
      }
      return $scope.$on('chain-shipment-save', function() {
        return $scope.reload($scope.shipment.id);
      });
    }
  ]);

}).call(this);
