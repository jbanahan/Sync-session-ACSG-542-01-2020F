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
        templateUrl: "vendor_portal/partials/main.html",
        controller: "MainCtrl"
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
  angular.module('VendorPortal').factory("AbstractBookOrder", [
    '$state', 'chainApiSvc', 'chainDomainerSvc', function($state, chainApiSvc, chainDomainerSvc) {
      return {
        restrict: 'E',
        scope: {
          order: '=',
          bookingFields: '=',
          bookingIncludes: "=?"
        },
        link: function(scope, el, attrs) {
          var loadModal;
          loadModal = function() {
            scope.loading = 'loading';
            return chainDomainerSvc.withDictionary().then(function(dict) {
              scope.dict = dict;
              return chainApiSvc.Shipment.openBookings(scope.bookingFields, scope.order.id, scope.bookingIncludes).then(function(shipments) {
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

  angular.module('VendorPortal').directive('chainVpBookOrder', [
    'AbstractBookOrder', function(AbstractBookOrder) {
      return $.extend({
        templateUrl: 'vendor_portal/partials/chain_vp_book_order.html'
      }, AbstractBookOrder);
    }
  ]);

  angular.module('VendorPortal').directive('llBookOrder', [
    'AbstractBookOrder', function(AbstractBookOrder) {
      return $.extend({
        templateUrl: 'vendor_portal/partials/ll/ll_book_order.html'
      }, AbstractBookOrder);
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').factory("AbstractBookings", [
    '$state', 'chainApiSvc', 'chainDomainerSvc', function($state, chainApiSvc, chainDomainerSvc) {
      return {
        restrict: 'E',
        scope: {
          order: '=',
          bookingFields: '=',
          bookingIncludes: "=?"
        },
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

  angular.module('VendorPortal').directive('chainVpBookings', [
    'AbstractBookings', function(AbstractBookings) {
      return $.extend({
        templateUrl: 'vendor_portal/partials/chain_vp_bookings.html'
      }, AbstractBookings);
    }
  ]);

  angular.module('VendorPortal').directive('llBookings', [
    'AbstractBookings', function(AbstractBookings) {
      return $.extend({
        templateUrl: 'vendor_portal/partials/ll/ll_bookings.html'
      }, AbstractBookings);
    }
  ]);

}).call(this);

(function() {
  angular.module('VendorPortal').directive('chainVpEditContainer', function() {
    return {
      restrict: 'E',
      scope: {
        dictionary: '=',
        detailColumns: '=?',
        headerColumns: '=?',
        detailFieldsTitle: '=?'
      },
      templateUrl: 'vendor_portal/partials/chain_vp_edit_container.html',
      link: function(scope, el, attrs) {
        var blankAttribute, emitSave, modalElement;
        if (!angular.isDefined(scope.detailFieldsTitle)) {
          scope.detailFieldsTitle = "Details";
        }
        if (angular.isDefined(scope.detailColumns)) {
          scope.detailColumnWidth = 12 / scope.detailColumns.length;
        } else {
          scope.detailColumns = [];
        }
        if (!angular.isDefined(scope.headerColumns)) {
          scope.headerColumns = [['con_container_number'], ['con_container_size'], ['con_seal_number']];
        }
        scope.headerColumnWidth = 12 / scope.headerColumns.length;
        scope.editContainer = {};
        scope.$on('chain-vp-edit-container', function(e, container, canEdit) {
          scope.canEdit = canEdit;
          scope.container = container;
          scope.editContainer = {};
          angular.merge(scope.editContainer, scope.container);
          return scope.showModal();
        });
        scope.showModal = function() {
          angular.merge(scope.editContainer, scope.container);
          modalElement().modal('show');
          return null;
        };
        modalElement = function() {
          return el.find('#chain-vp-edit-container');
        };
        emitSave = function() {
          modalElement().off("hidden.bs.modal");
          return scope.$emit("chain-vp-container-added", scope.container);
        };
        blankAttribute = function(obj, fld) {
          var val;
          val = obj[fld.uid];
          if (val === null || val === void 0) {
            return true;
          }
          if (val.toString) {
            val = val.toString();
            return !val.trim();
          } else {
            return false;
          }
        };
        scope.canSaveContainer = function() {
          if (blankAttribute(scope.editContainer, scope.dictionary.field("con_container_number"))) {
            return false;
          }
          if (blankAttribute(scope.editContainer, scope.dictionary.field("con_container_size"))) {
            return false;
          }
          return true;
        };
        scope.saveContainer = function() {
          var modal;
          angular.merge(scope.container, scope.editContainer);
          scope.editContainer = {};
          modal = modalElement();
          modal.on('hidden.bs.modal', emitSave);
          modal.modal('hide');
          return null;
        };
        return scope.cancel = function() {
          scope.editContainer = {};
          scope.container = {};
          el.find('.modal').modal('hide');
          return null;
        };
      }
    };
  });

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
        scope.numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20];
        writeReqVal = function(rEquip, row) {
          var elements;
          elements = row.split(' ');
          if (elements.length !== 2) {
            return;
          }
          return rEquip[elements[1]] = elements[0];
        };
        parseExistingValue = function(shp) {
          var e, i, j, len, len1, ref, reqRows, reqStr, requestedEquipment, row;
          requestedEquipment = {};
          ref = scope.equipmentTypes;
          for (i = 0, len = ref.length; i < len; i++) {
            e = ref[i];
            requestedEquipment[e] = 0;
          }
          reqStr = shp.shp_requested_equipment;
          if (reqStr && reqStr.length > 0) {
            reqRows = reqStr.split("\n");
            for (j = 0, len1 = reqRows.length; j < len1; j++) {
              row = reqRows[j];
              writeReqVal(requestedEquipment, row);
            }
          }
          return requestedEquipment;
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
            if (!isNaN(num) && num > 0) {
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
  angular.module('VendorPortal').directive('chainVpManifestBookingLines', [
    '$window', 'chainApiSvc', function($window, chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          shipment: '=',
          dictionary: '=',
          lineEditFields: "=",
          requiredEditFields: "="
        },
        templateUrl: 'vendor_portal/partials/chain_vp_manifest_booking_lines.html',
        link: function(scope, el, attrs) {
          var blankAttribute, fld, i, j, len, len1, ref, ref1;
          scope.manifestingLines = [];
          scope.additionalFields = [];
          scope.requiredFields = [];
          ref = scope.lineEditFields;
          for (i = 0, len = ref.length; i < len; i++) {
            fld = ref[i];
            scope.additionalFields.push(scope.dictionary.field(fld));
          }
          ref1 = scope.requiredEditFields;
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            fld = ref1[j];
            scope.requiredFields.push(scope.dictionary.field(fld));
          }
          scope.standardViewFields = ['bkln_order_number', 'bkln_puid', 'bkln_quantity'];
          scope.standardEditFields = [scope.dictionary.field('shpln_shipped_qty')];
          scope.buildManifestLines = function() {
            var bl, k, l, len2, len3, ref2, ref3, results, shipment_line;
            scope.manifestingLines = [];
            ref2 = scope.shipment.booking_lines;
            results = [];
            for (k = 0, len2 = ref2.length; k < len2; k++) {
              bl = ref2[k];
              shipment_line = {
                shpln_line_number: bl.bkln_line_number,
                linked_order_line_id: bl.bkln_order_line_id,
                shpln_shipped_qty: bl.bkln_quantity,
                shpln_container_id: null,
                shpln_prod_id: bl.bkln_product_db_id,
                bkln_order_number: bl.bkln_order_number,
                bkln_quantity: bl.bkln_quantity,
                bkln_puid: bl.bkln_puid
              };
              ref3 = scope.additionalFields;
              for (l = 0, len3 = ref3.length; l < len3; l++) {
                fld = ref3[l];
                shipment_line[fld.uid] = null;
              }
              results.push(scope.manifestingLines.push(shipment_line));
            }
            return results;
          };
          scope.showModal = function() {
            scope.buildManifestLines();
            el.find(".modal").modal("show");
            return null;
          };
          scope.saveShipmentLines = function() {
            return scope.closeModal(function() {
              return scope.$emit("chain-vp-shipment-lines-added", scope.manifestingLines);
            });
          };
          scope.cancel = function() {
            scope.manifestingLines = [];
            return scope.closeModal();
          };
          scope.closeModal = function(callback) {
            var modal;
            modal = el.find('.modal');
            if (callback) {
              modal.on('hidden.bs.modal', function() {
                return callback();
              });
            }
            modal.modal('hide');
            return null;
          };
          blankAttribute = function(obj, fld) {
            var val;
            val = obj[fld.uid];
            if (val === null || val === void 0) {
              return true;
            }
            if (val.toString) {
              val = val.toString();
              return !val.trim();
            } else {
              return false;
            }
          };
          return scope.canSaveLines = function() {
            var k, l, len2, len3, line, ref2, ref3;
            ref2 = scope.manifestingLines;
            for (k = 0, len2 = ref2.length; k < len2; k++) {
              line = ref2[k];
              if (isNaN(parseInt(line.shpln_container_id)) || parseInt(line.shpln_container_id) === 0) {
                return false;
              }
              if (isNaN(parseInt(line.shpln_shipped_qty)) || parseInt(line.shpln_shipped_qty) <= 0) {
                return false;
              }
              ref3 = scope.requiredFields;
              for (l = 0, len3 = ref3.length; l < len3; l++) {
                fld = ref3[l];
                if (blankAttribute(line, fld)) {
                  return false;
                }
              }
            }
            return true;
          };
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
              "class": 'btn btn-sm btn-outline-dark',
              iconClass: 'fa fa-eye',
              onClick: $scope.showOrder
            }
          ],
          bulkSelections: true
        };
      };
      $scope.showOrder = function(ord, $event) {
        var url;
        if ($event && $event.ctrlKey) {
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
      $scope.pageUid = 'chain-vp-shipment-panel';
      $scope.baseSearch = function() {
        var ss;
        return ss = {
          buttons: [
            {
              label: 'View',
              "class": 'btn btn-sm btn-outline-dark',
              iconClass: 'fa fa-eye',
              onClick: $scope.showShipment
            }
          ],
          bulkSelections: true
        };
      };
      $scope.showShipment = function(shp, evt) {
        var url;
        if (evt && evt.ctrlKey) {
          url = $state.href('showShipment', {
            id: shp.id
          });
          $window.open(url, '_blank');
        } else {
          $state.transitionTo('showShipment', {
            id: shp.id
          });
        }
        return null;
      };
      return $scope.hasSelections = function() {
        return bulkSelectionSvc.selectedCount($scope.pageUid) > 0;
      };
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

angular.module('VendorPortal-Templates', ['vendor_portal/partials/chain_vp_book_order.html', 'vendor_portal/partials/chain_vp_bookings.html', 'vendor_portal/partials/chain_vp_edit_container.html', 'vendor_portal/partials/chain_vp_equipment_requestor.html', 'vendor_portal/partials/chain_vp_full_shipment_pack.html', 'vendor_portal/partials/chain_vp_manifest_booking_lines.html', 'vendor_portal/partials/chain_vp_order_panel.html', 'vendor_portal/partials/chain_vp_shipment_panel.html', 'vendor_portal/partials/chain_vp_variant_selector.html', 'vendor_portal/partials/ll/ll_book_order.html', 'vendor_portal/partials/ll/ll_bookings.html', 'vendor_portal/partials/main.html', 'vendor_portal/partials/order_accept_button.html', 'vendor_portal/partials/select_ship_from.html', 'vendor_portal/partials/select_tpp_survey_response.html', 'vendor_portal/partials/standard_order_template.html', 'vendor_portal/partials/standard_shipment_template.html']);

angular.module("vendor_portal/partials/chain_vp_book_order.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_book_order.html",
    "<button class=\"btn btn-sm btn-primary\" ng-if=\"order.permissions.can_book\" ng-click=\"showModal()\">Book Order</button><div class=\"modal fade text-left\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Select Shipment</h4></div><div class=\"modal-body\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><table class=\"table\" ng-hide=\"loading\"><thead><tr><th>{{dict.field('shp_ref').label}}</th><th>{{dict.field('shp_booked_orders').label}}</th><th>&nbsp;</th></tr></thead><tbody><tr ng-repeat=\"s in shipments track by s.id\"><td><chain-field-value model=\"s\" field='dict.field(\"shp_ref\")'></chain-field-value></td><td><chain-field-value model=\"s\" field='dict.field(\"shp_booked_orders\")'></chain-field-value></td><td><button class=\"btn btn-sm btn-success\" title=\"Add to shipment\" ng-click=\"addToShipment(s)\"><i class=\"fa fa-plus\"></i></button></td></tr><tr><td colspan=\"3\"><button class=\"btn btn-success\" title=\"Add to NEW shipment\" ng-click=\"addToNewShipment()\">Create New Shipment</button></td></tr></tbody></table></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_bookings.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_bookings.html",
    "<small ng-if=\"loading\">Loading bookings</small><chain-vp-book-order order=\"order\" booking-fields=\"bookingFields\" ng-if=\"shipments.length==0\"></chain-vp-book-order><span ng-repeat=\"s in shipments track by s.id\"><a ui-sref=\"showShipment(s)\">{{s.shp_ref}}</a><span ng-if=\"!$last\">,</span></span>");
}]);

angular.module("vendor_portal/partials/chain_vp_edit_container.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_edit_container.html",
    "<div id=\"chain-vp-edit-container\" class=\"modal fade\" data-backdrop=\"static\" data-keyboard=\"false\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\" data-backdrop=\"static\" data-keyboard=\"false\"><div class=\"modal-dialog modal-lg\"><div class=\"modal-content text-left\"><div class=\"modal-header\"><h4 ng-if=\"editContainer.id\" class=\"modal-title\">Edit Container</h4><h4 ng-if=\"!editContainer.id\" class=\"modal-title\">Create Container</h4></div><div class=\"modal-body\"><div class=\"row\"><div ng-repeat=\"fields in headerColumns track by $index\" class=\"col-md-{{headerColumnWidth}}\"><ul class=\"list-group\"><li class=\"list-group-item\" ng-repeat=\"fld in fields track by $index\"><chain-field-label field=\"dictionary.field(fld)\"></chain-field-label><div ng-if=\"canEdit\"><chain-field-input model=\"editContainer\" field=\"dictionary.field(fld)\"></chain-field-input></div><div ng-if=\"!canEdit\"><chain-field-value model=\"editContainer\" field=\"dictionary.field(fld)\"></chain-field-value></div></li></ul></div></div><div ng-if=\"detailColumns.length > 0\"><hr><h4>{{detailFieldsTitle}}</h4><div class=\"row\"><div ng-repeat=\"fields in detailColumns track by $index\" class=\"col-md-{{detailColumnWidth}}\"><ul class=\"list-group\"><li class=\"list-group-item\" ng-repeat=\"fld in fields track by $index\"><chain-field-label field=\"dictionary.field(fld)\"></chain-field-label><div ng-if=\"canEdit\"><chain-field-input model=\"editContainer\" field=\"dictionary.field(fld)\"></chain-field-input></div><div ng-if=\"!canEdit\"><chain-field-value model=\"editContainer\" field=\"dictionary.field(fld)\"></chain-field-value></div></li></ul></div></div></div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn\" ng-click=\"cancel()\">Cancel</button> <button type=\"button\" class=\"btn btn-primary\" ng-click=\"saveContainer()\" ng-disabled=\"!canSaveContainer()\" )>Save</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_equipment_requestor.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_equipment_requestor.html",
    "<pre>\n" +
    "{{shipment.shp_requested_equipment}}\n" +
    "</pre><button class=\"btn btn-sm btn-primary\" ng-show=\"shipment.permissions.can_edit\" ng-click=\"showModal()\">Change</button><div class=\"modal fade\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Equipment Request</h4><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button></div><div class=\"modal-body\"><div class=\"form-group\" ng-repeat=\"et in equipmentTypes track by $index\"><label>{{et}}</label><select class=\"form-control\" ng-options=\"n for n in numbers track by n\" ng-model=\"requestedEquipment[et]\"></select></div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn\" data-dismiss=\"modal\">Cancel</button> <button type=\"button\" class=\"btn btn-primary\" ng-click=\"commitChange()\">OK</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_full_shipment_pack.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_full_shipment_pack.html",
    "<button ng-click=\"showModal(shipment)\" ng-disabled=\"!shipment.permissions.can_add_remove_shipment_lines || shipment.shp_shipment_instructions_sent_date || unShippedBookingLines.length == 0\" class=\"btn btn-default\">Pack Manifest</button><div class=\"modal fade\" data-backdrop=\"static\" data-keyboard=\"false\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\" data-backdrop=\"static\" data-keyboard=\"false\"><div class=\"modal-dialog\"><div class=\"modal-content text-left\"><div class=\"modal-header\"><h4 class=\"modal-title\">Pack Shipment</h4></div><div class=\"modal-body\"><h4>Available Booking Lines</h4><div class=\"alert alert-success\" ng-show=\"unShippedBookingLines.length>0\">All lines must be packed to save shipment.</div><table class=\"table available-lines\"><thead><tr><th></th><th ng-repeat=\"uid in bookingTableFields track by $index\">{{dictionary.field(uid).label}}</th></tr></thead><tbody><tr ng-repeat=\"bl in unShippedBookingLines track by bl.id\"><td><input type=\"checkbox\" ng-model=\"bl.readyForPack\"></td><td ng-repeat=\"uid in bookingTableFields track by $index\">{{bl[uid]}}</td></tr></tbody></table><div class=\"text-right\"><label>Container</label><select class=\"form-control\" ng-model=\"containerToPack\" ng-options=\"con.con_container_number for con in shipment.containers\"></select><button class=\"btn\" ng-click=\"packLines(shipment,containerToPack)\">Pack Lines</button></div><h4>Containers</h4><table class=\"table containers\"><thead><tr><th ng-repeat=\"uid in containerTableFields track by $index\">{{dictionary.field(uid).label}}</th><th><button class=\"btn btn-sm btn-success\" ng-show=\"!showAddContainer\" ng-click=\"showAddContainer = true\" title=\"Show Add Container\"><i class=\"fa fa-plus\"></i></button> <button class=\"btn btn-sm btn-success\" ng-show=\"showAddContainer\" ng-click=\"showAddContainer = false\" title=\"Hide Add Container\"><i class=\"fa fa-minus\"></i></button></th></tr></thead><tbody><tr class=\"add-container-row\" ng-show=\"showAddContainer\"><td ng-repeat=\"uid in containerTableFields track by $index\"><chain-field-input model=\"containerToAdd\" field=\"dictionary.field(uid)\"></chain-field-input></td><td><button class=\"btn btn-xm btn-success\" ng-disabled=\"shouldDisableAddContainer()\" title=\"Add Container\" ng-click=\"addContainer(shipment,containerToAdd)\"><i class=\"fa fa-plus\"></i></button></td></tr></tbody><tbody ng-repeat=\"con in shipment.containers track by con.id\"><tr class=\"info\"><td ng-repeat=\"uid in containerTableFields track by $index\"><chain-field-value model=\"con\" field=\"dictionary.field(uid)\"></chain-field-value></td><td></td></tr><tr><td colspan=\"{{containerTableFields.length + 1}}\"><table class=\"table\" ng-show=\"linesForContainer(shipment,con).length > 0\"><thead><tr><td ng-repeat=\"uid in shipmentLineTableFields track by $index\">{{dictionary.field(uid).label}}</td></tr></thead><tbody><tr ng-repeat=\"ln in linesForContainer(shipment,con)\"><td ng-repeat=\"uid in shipmentLineTableFields track by $index\"><chain-field-value model=\"ln\" field=\"dictionary.field(uid)\"></chain-field-value></td></tr></tbody></table><div class=\"text-warning\" ng-show=\"linesForContainer(shipment,con).length == 0\">Empty containers will be removed when you save.</div></td></tr></tbody></table></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn\" ng-click=\"cancel(shipment)\">Cancel</button> <button type=\"button\" class=\"btn btn-primary\" ng-disabled=\"!canSave(shipment)\" ng-click=\"save(shipment)\">Save</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_manifest_booking_lines.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_manifest_booking_lines.html",
    "<button ng-click=\"showModal(shipment)\" ng-disabled=\"!shipment.permissions.can_add_remove_shipment_lines || shipment.shipment_lines.length > 0 || shipment.containers.length == 0 || shipment.booking_lines.length == 0\" class=\"btn btn-default\">Pack Manifest</button><div class=\"modal fade\" data-backdrop=\"static\" data-keyboard=\"false\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\" data-backdrop=\"static\" data-keyboard=\"false\"><div class=\"modal-dialog modal-xl\"><div class=\"modal-content text-left\"><div class=\"modal-header\"><h4 class=\"modal-title\">Pack Shipment</h4></div><div class=\"modal-body\"><h4>Available Booking Lines</h4><div class=\"alert alert-success\">All lines must be packed in order to save.</div><table class=\"table available-lines\"><thead><tr><th>{{dictionary.field('con_container_number').label}}</th><th ng-repeat=\"uid in standardViewFields track by $index\">{{dictionary.field(uid).label}}</th><th ng-repeat=\"fld in standardEditFields track by $index\">{{fld.label}}</th><th ng-repeat=\"fld in additionalFields track by $index\">{{fld.label}}</th></tr></thead><tbody><tr ng-repeat=\"line in manifestingLines track by line.shpln_line_number\"><td><select class=\"form-control\" ng-model=\"line.shpln_container_id\" ng-options=\"c.id as c.con_container_number for c in shipment.containers\" style=\"width: 12em\"></select></td><td ng-repeat=\"uid in standardViewFields track by $index\">{{line[uid]}}</td><td ng-repeat=\"fld in standardEditFields track by $index\"><chain-field-input model=\"line\" field=\"fld\"></chain-field-input></td><td ng-repeat=\"fld in additionalFields track by $index\"><chain-field-input model=\"line\" field=\"fld\"></chain-field-input></td></tr></tbody></table></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn\" ng-click=\"cancel()\">Cancel</button> <button type=\"button\" class=\"btn btn-primary\" ng-disabled=\"!canSaveLines()\" ng-click=\"saveShipmentLines()\">Save</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/chain_vp_order_panel.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_order_panel.html",
    "<chain-search-panel name=\"Orders\" api-object-name=\"Order\" base-search-setup-function=\"baseSearch\" page-uid=\"{{pageUid}}\" bulk-edit=\"true\" cache-hidden-criteria=\"true\"><chain-bulk-edit api-object-name=\"Order\" page-uid=\"{{pageUid}}\" button-classes=\"btn btn-sm btn-outline-dark\"></chain-bulk-edit><chain-bulk-comment api-object-name=\"Order\" page-uid=\"{{pageUid}}\" button-classes=\"btn btn-sm btn-outline-dark\"></chain-bulk-comment><button class=\"btn btn-sm btn-outline-dark\" ng-click=\"bulkApprove()\" ng-disabled=\"!hasSelections()\">Approve</button></chain-search-panel>");
}]);

angular.module("vendor_portal/partials/chain_vp_shipment_panel.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_shipment_panel.html",
    "<chain-search-panel name=\"Shipments\" api-object-name=\"Shipment\" base-search-setup-function=\"baseSearch\" page-uid=\"{{pageUid}}\" bulk-edit=\"true\" cache-hidden-criteria=\"true\"><chain-bulk-edit api-object-name=\"Shipment\" page-uid=\"{{pageUid}}\" button-classes=\"btn btn-sm btn-outline-dark\"></chain-bulk-edit><chain-bulk-comment api-object-name=\"Shipment\" page-uid=\"{{pageUid}}\" button-classes=\"btn btn-sm btn-outline-dark\"></chain-bulk-comment></chain-search-panel>");
}]);

angular.module("vendor_portal/partials/chain_vp_variant_selector.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/chain_vp_variant_selector.html",
    "<span>{{orderLine.ordln_varuid}}</span> <button class=\"btn btn-sm\" ng-if=\"canEdit\" title=\"Change Variant\" ng-click=\"activateModal()\"><i class=\"fa fa-edit\"></i></button><div class=\"modal fade\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Change Variant</h4></div><div class=\"modal-body\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><div class=\"card\" ng-repeat=\"v in variants track by v.id\" ng-class=\"{'card-primary':v==selectedVariant,'card-default':v!=selectedVariant}\"><div class=\"card-header\">{{v.var_identifier}}</div><div class=\"card-body\"><pre>\n" +
    "{{v[dictionary.fieldsByAttribute('label','Recipe',dictionary.fieldsByRecordType(dictionary.recordTypes.Variant))[0].uid]}}\n" +
    "</pre></div><div class=\"card-footer text-right\"><button class=\"btn btn-primary btn-sm\" title=\"Select Variant\" ng-click=\"selectVariant(v)\">Select</button></div></div><div ng-show=\"variants && variants.length==0 && !loading\" class=\"text-danger\">No variants are assigned to this product.</div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn\" data-dismiss=\"modal\">Close</button> <button type=\"button\" class=\"btn btn-success\" ng-disabled=\"!selectedVariant || loading\" ng-click=\"save()\">Save</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/ll/ll_book_order.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/ll/ll_book_order.html",
    "<button class=\"btn btn-sm btn-primary\" ng-click=\"showModal()\">Book Order</button><div class=\"modal fade text-left\"><div class=\"modal-dialog modal-lg\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Select Shipment</h4></div><div class=\"modal-body\"><p><i>Only eligible orders with the same Delivery Location and Ship To can be added to an existing booking.</i></p><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><table class=\"table\" ng-hide=\"loading\"><thead><tr><th>{{dict.field('shp_ref').label}}</th><th>{{dict.field('shp_first_port_receipt_id').label}}</th><th>Ship To</th><th>{{dict.field('shp_booked_orders').label}}<br>(Forecasted Ship Windows)</th><th>&nbsp;</th></tr></thead><tbody><tr ng-repeat=\"s in shipments track by s.id\"><td ng-style=\"s.permissions.can_book_order_to_shipment ? {} : {'color':'gray'}\"><chain-field-value model=\"s\" field='dict.field(\"shp_ref\")'></chain-field-value></td><td ng-style=\"s.permissions.can_book_order_to_shipment ? {} : {'color':'gray'}\"><chain-field-value model=\"s\" field='dict.field(\"shp_first_port_receipt_code\")'></chain-field-value></td><td ng-style=\"s.permissions.can_book_order_to_shipment ? {} : {'color':'gray'}\"><chain-address address=\"{{s.shp_ship_to_address_full_address}}\"></chain-address></td><td ng-style=\"s.permissions.can_book_order_to_shipment ? {} : {'color':'gray'}\"><div ng-repeat=\"order in s.booked_orders track by order.id\"><chain-field-value model=\"order\" field='dict.field(\"ord_ord_num\")'></chain-field-value><br>(<chain-field-value model=\"order\" field='dict.field(\"*ord_forecasted_ship_window_start\")'></chain-field-value>&nbsp;/&nbsp;<chain-field-value model=\"order\" field='dict.field(\"*ord_forecasted_ship_window_end\")'></chain-field-value>)</div></td><td><button ng-if=\"s.permissions.can_book_order_to_shipment\" class=\"btn btn-sm btn-success\" title=\"Add to shipment\" ng-click=\"addToShipment(s)\"><i class=\"fa fa-plus\"></i></button></td></tr><tr><td colspan=\"5\"><button class=\"btn btn-success\" title=\"Add to NEW shipment\" ng-click=\"addToNewShipment()\">Create New Shipment</button></td></tr></tbody></table></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/ll/ll_bookings.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/ll/ll_bookings.html",
    "<small ng-if=\"loading\">Loading bookings</small><ll-book-order order=\"order\" booking-fields=\"bookingFields\" booking-includes=\"bookingIncludes\" ng-if=\"shipments.length==0\"></ll-book-order><span ng-repeat=\"s in shipments track by s.id\"><a ui-sref=\"showShipment(s)\">{{s.shp_ref}}</a><span ng-if=\"!$last\">,</span></span>");
}]);

angular.module("vendor_portal/partials/main.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/main.html",
    "<div class=\"container\"><div class=\"row\"><div class=\"col-md-12 text-center\"><a ui-sref=\"main\"><img src=\"/logo.png\" alt=\"Logo\" class=\"img-responsive\" style=\"margin: 0 auto\"></a><br><h1>Vendor Portal</h1></div></div><div class=\"row\"><div class=\"col-12 d-lg-none d-xl-none pb-2\"><div class=\"card\"><div class=\"card-header font-weight-bold\">Settings</div><div class=\"card-body\"><a href=\"#\" class=\"change-password-link\">Change Password</a></div></div></div><div class=\"col-md-12 col-lg-10\"><chain-vp-order-panel ng-if=\"me.permissions.view_orders\"></chain-vp-order-panel><chain-vp-shipment-panel ng-if=\"me.permissions.view_shipments\"></chain-vp-shipment-panel></div><div class=\"col-lg-2 d-none d-lg-block\"><div class=\"card\"><div class=\"card-header font-weight-bold\">Settings</div><div class=\"card-body\"><a href=\"#\" class=\"change-password-link\">Change Password</a></div></div></div></div><chain-change-password-modal></chain-change-password-modal><script>$('.change-password-link').click(function() {\n" +
    "      $('chain-change-password-modal .modal').modal('show');\n" +
    "      return false;\n" +
    "    });</script></div>");
}]);

angular.module("vendor_portal/partials/order_accept_button.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/order_accept_button.html",
    "<button class='btn btn-sm {{order.ord_approval_status!=\"Accepted\" ? \"btn-success\" : \"btn-link\"}}' ng-if=\"order.permissions.can_accept && (order.permissions.can_be_accepted || order.ord_approval_status=='Accepted')\" ng-click=\"toggleAccept(order)\"><span ng-show=\"order.ord_approval_status!='Accepted'\">Approve</span> <span ng-show=\"order.ord_approval_status=='Accepted'\" class=\"fa fa-trash text-danger\" title=\"Remove\"></span></button>");
}]);

angular.module("vendor_portal/partials/select_ship_from.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/select_ship_from.html",
    "<div class=\"card\"><div class=\"card-header\"><a ui-sref=\"showOrder({id:order.id})\"><i class=\"fa fa-arrow-left\"></i></a>&nbsp;Select Ship From Address</div><div class=\"card-body\"><div class=\"row\" ng-repeat=\"ag in addressGroups\"><div class=\"col-md-4\" ng-repeat=\"a in ag track by a.id\"><div class=\"thumbnail\"><iframe ng-src=\"{{a.map_url}}\" style=\"width:100%\"></iframe><div class=\"caption\"><div class=\"text-right text-warning\"><small>Map locations are approximate based on the address text provided.</small></div><div><chain-address address=\"{{a.add_full_address}}\"></chain-address></div><div class=\"text-right\"><button ng-click=\"select(order,a)\" class=\"btn btn-success\" role=\"button\">Select</button></div></div></div></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/select_tpp_survey_response.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/select_tpp_survey_response.html",
    "<chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><div class=\"card\" ng-show='loading!=\"loading\"'><div class=\"card-header\"><a ui-sref=\"showOrder(order.id)\"><i class=\"fa fa-arrow-left\"></i></a>&nbsp;Select Trade Preference Program Certification</div><div class=\"card-body\"><select class=\"form-control\" title=\"Select TPP Certification\" ng-model=\"tppSurveyResponse\" ng-options=\"a.long_name for a in availableResponses\"></select></div><div class=\"card-footer text-right\"><button class=\"btn\" ng-click=\"showOrder(order.id)\">Cancel</button> <button class=\"btn btn-primary\" ng-click=\"select(order)\">Select</button></div></div>");
}]);

angular.module("vendor_portal/partials/standard_order_template.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/standard_order_template.html",
    "<div class=\"container\" id=\"standard-order-template\"><div class=\"row\"><div class=\"col-md-12 text-center\"><a ui-sref=\"main\"><img src=\"/logo.png\" alt=\"Logo\"></a><br><h1><small>Purchase Order</small><br>{{order.ord_ord_num}}</h1></div></div><div class=\"row\"><div class=\"col-md-5\"><div class=\"card\"><div class=\"card-header\"></div><ul class=\"list-group\"><li class=\"list-group-item\">Issue Date <span class=\"float-right\">{{order.ord_ord_date}}</span></li><li class=\"list-group-item\" ng-if=\"order.ord_window_start && order.ord_window_start==order.ord_window_end\">Delivery Date <span class=\"float-right\">{{order.ord_window_start}}</span></li><li class=\"list-group-item\" ng-if=\"order.ord_window_start && order.ord_window_start!=order.ord_window_end\">Ship Window Start <span class=\"float-right\">{{order.ord_window_start}}</span></li><li class=\"list-group-item\" ng-if=\"order.ord_window_end && order.ord_window_start!=order.ord_window_end\">Ship Window End <span class=\"float-right\">{{order.ord_window_end}}</span></li><li class=\"list-group-item\">Vendor No. <span class=\"float-right\">{{order.ord_ven_syscode}}</span></li><li class=\"list-group-item\">Vendor Name <span class=\"float-right\">{{order.ord_ven_name}}</span></li><li class=\"list-group-item\">Currency <span class=\"float-right\">{{order.ord_currency}}</span></li><li class=\"list-group-item\">Terms of Payment <span class=\"float-right\">{{order.ord_payment_terms}}</span></li><li class=\"list-group-item\">Terms of Delivery <span class=\"float-right\">{{order.ord_terms}}</span></li><li class=\"list-group-item\">Delivery Location <span class=\"float-right\">{{order.ord_fob_point}}</span></li></ul></div><div class=\"card\"><div class=\"card-header\">Order Status</div><ul class=\"list-group\"><li class=\"list-group-item\">Vendor Approval <span class=\"float-right\">{{order.ord_approval_status}} <a class=\"label label-default\" ng-if='!order.permissions.can_be_accepted && order.ord_approval_status!=\"Accepted\"' data-toggle=\"modal\" data-target=\"#mod_cant_be_accepted\">Not Ready</a><order-accept-button></order-accept-button></span></li></ul></div></div><div class=\"col-md-7\"><div class=\"card\"><div class=\"card-header\">Vendor Order Address</div><div class=\"card-body\"><chain-address address=\"{{order.ord_order_from_address_full_address}}\"></chain-address></div></div><div class=\"card\"><div class=\"card-header\"><h3 class=\"card-title\">Ship From Address</h3></div><div class=\"card-body\"><div class=\"text-warning\" ng-show=\"order.permissions.can_edit && order.vendor_id == me.company_id && !order.ord_ship_from_full_address.length>0\">Please select a ship from address using the Change button below.</div><chain-address address=\"{{order.ord_ship_from_full_address}}\"></chain-address></div><div class=\"card-footer text-right\" ng-if=\"order.permissions.can_edit && order.vendor_id == me.company_id\"><a ui-sref=\"selectShipFrom({id:order.id})\" class=\"btn btn-primary\">Change</a></div></div><div class=\"card\"><div class=\"card-header\">Ship To Address</div><div ng-if=\"order.order_lines.length > 0 && order.ord_ship_to_count==1\" class=\"card-body\"><chain-address address=\"{{order.order_lines[0].ordln_ship_to_full_address}}\"></chain-address></div><div ng-if=\"order.ord_ship_to_count > 1\" class=\"card-body\"><strong>Multi-Stop</strong></div></div><div class=\"card\" ng-if=\"order.available_tpp_survey_responses.length > 0\"><div class=\"card-header\">Trade Preference Program Certification</div><div class=\"card-body\">{{order.ord_tppsr_name}}<div ng-if=\"!order.ord_tppsr_db_id\" class=\"alert alert-info\">No trade preference program selected.</div></div><div class=\"card-footer text-right\"><button class=\"btn btn-primary\" ui-sref=\"selectTppSurveyResponse({id:order.id})\">Change</button></div></div></div></div><div class=\"row\"><div class=\"col-md-12\"><div class=\"card\"><table class=\"table table-bordered table-striped\"><thead><tr><th>Line Num</th><th>Article</th><th ng-if=\"order.ord_ship_to_count > 1\">Ship To</th><th>Quantity</th><th>UM</th><th>Unit Price</th><th>Net Amount</th></tr></thead><tbody><tr ng-repeat=\"ol in order.order_lines track by ol.id\"><td>{{ol.ordln_line_number}}</td><td><small>{{ol.ordln_puid}}</small><br>{{ol.ordln_pname}}</td><td ng-if=\"order.ord_ship_to_count > 1\"><chain-address address=\"{{ol.ordln_ship_to_full_address}}\"></chain-address></td><td class=\"text-right numeric\">{{ol.ordln_ordered_qty}}</td><td>{{ol.ordln_unit_of_measure}}</td><td class=\"text-right numeric\">{{ol.ordln_ppu}}</td><td class=\"text-right numeric\">{{ol.ordln_total_cost}}</td></tr><tr><td class=\"text-right\" colspan=\"5\">Total</td><td class=\"text-right numeric\">{{order.ord_total_cost}}</td></tr></tbody></table></div></div></div><div class=\"row\"><div class=\"col-md-6\"><chain-comments-panel parent=\"order\" module-type=\"Order\"></chain-comments-panel></div><div class=\"col-md-6\"><chain-attachments-panel parent=\"order\" module-type=\"Order\"></chain-attachments-panel></div></div></div><div class=\"modal fade\" id=\"mod_cant_be_accepted\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Pending Updates</h4></div><div class=\"modal-body\">This order is does not have all data elements completed and cannot be accepted.</div><div class=\"modal-footer\"><button type=\"button\" class=\"btn\" data-dismiss=\"modal\">Close</button></div></div></div></div>");
}]);

angular.module("vendor_portal/partials/standard_shipment_template.html", []).run(["$templateCache", function ($templateCache) {
  $templateCache.put("vendor_portal/partials/standard_shipment_template.html",
    "<div id=\"standard-shipment-template\"><h1>Shipment {{shipment.shp_ref}}</h1></div>");
}]);

(function() {
  var app;

  app = angular.module('VendorPortal');

  app.controller('MainCtrl', [
    '$scope', 'chainApiSvc', function($scope, chainApiSvc) {
      $scope.init = function() {
        return chainApiSvc.User.me().then(function(me) {
          return $scope.me = me;
        });
      };
      if (!$scope.$root.isTest) {
        return $scope.init();
      }
    }
  ]);

}).call(this);

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
          return chainApiSvc.Shipment.get(id, {
            include: "order_lines,containers,shipment_lines,booking_lines,state_toggle_buttons"
          }).then(function(shipment) {
            $scope.shipment = shipment;
            $scope.$broadcast('chain-shipment-loaded', shipment);
            return delete $scope.loading;
          });
        });
      };
      $scope.reload = function(id) {
        $scope.loading = 'loading';
        return chainApiSvc.Shipment.load(id, {
          include: "order_lines,containers,shipment_lines,booking_lines,state_toggle_buttons"
        }).then(function(s) {
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
      $scope.editContainer = function(container) {
        return $scope.$broadcast('chain-vp-edit-container', container, $scope.shipment.permissions.can_add_remove_shipment_lines);
      };
      $scope.addContainer = function() {
        var container;
        container = {
          id: 0
        };
        return $scope.editContainer(container);
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
        var i, len, ln, nullFunc, ref, shpToSave;
        if ($window.confirm("Are you sure you want to clear the manifest and start over?")) {
          nullFunc = function(shp) {
            var d;
            d = $q.defer();
            d.resolve(shp);
            return d.promise;
          };
          shpToSave = {
            id: shp.id,
            lines: []
          };
          ref = shp.lines;
          for (i = 0, len = ref.length; i < len; i++) {
            ln = ref[i];
            shpToSave.lines.push({
              id: ln.id,
              _destroy: true
            });
          }
          return saveAndAct(shpToSave, shp.permissions.can_add_remove_shipment_lines, "You do not have permission to remove lines from this shipment.", nullFunc);
        }
      };
      $scope.canDeleteContainer = function(container) {
        var i, len, line, ref;
        ref = $scope.shipment.lines;
        for (i = 0, len = ref.length; i < len; i++) {
          line = ref[i];
          if (line.shpln_container_id === container.id) {
            return false;
          }
        }
        return true;
      };
      $scope.deleteContainer = function(container) {
        var c, i, len, ref;
        ref = $scope.shipment.containers;
        for (i = 0, len = ref.length; i < len; i++) {
          c = ref[i];
          if (c.id === container.id) {
            if (!$window.confirm("Are you sure you want to delete Container " + container.con_container_number + "?")) {
              return false;
            } else {
              c["_destroy"] = true;
            }
          }
        }
        return $scope.save($scope.shipment);
      };
      $scope.stateToggleButton = function(identifier) {
        var b, i, len, ref;
        ref = $scope.shipment.state_toggle_buttons;
        for (i = 0, len = ref.length; i < len; i++) {
          b = ref[i];
          if (b.identifier === identifier) {
            return b;
          }
        }
        return null;
      };
      $scope.complexStateToggleButtons = function() {
        var b, buttons, i, len, ref;
        buttons = [];
        ref = $scope.shipment.containers;
        for (i = 0, len = ref.length; i < len; i++) {
          b = ref[i];
          if (b.simple_button === null || !b.simple_button) {
            buttons.push(b);
          }
        }
        return buttons;
      };
      $scope.scopedReload = function() {
        return $scope.reload($scope.shipment.id);
      };
      if (!$scope.$root.isTest) {
        $scope.init($stateParams.id);
      }
      $scope.$on('chain-shipment-save', function() {
        return $scope.scopedReload();
      });
      $scope.$on("chain-vp-container-added", function(e, container) {
        if (container.id === 0) {
          $scope.shipment.containers.push(container);
        }
        return $scope.save($scope.shipment);
      });
      $scope.$on("chain-vp-shipment-lines-added", function(e, lines) {
        var i, len, line;
        for (i = 0, len = lines.length; i < len; i++) {
          line = lines[i];
          $scope.shipment.lines.push(line);
        }
        return $scope.save($scope.shipment);
      });
      return null;
    }
  ]);

}).call(this);
