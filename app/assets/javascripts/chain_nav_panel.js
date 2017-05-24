/*Generated file from the chain_nav_panel project. DO NOT EDIT DIRECTLY*/
(function() {
  var root;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  root.ChainNavPanel = {
    write: function(htmlWrapper, elementToReplace, userPromise, notificationCenterCallback) {
      var initNotificationCenter, registerHotKeys, setupHomepageModal, setupOffCanvas, setupSupportRequestModal, writeMenu;
      registerHotKeys = function() {
        return $(document).on('keyup', function(evt) {
          if ($(evt.target).is(':input')) {
            return;
          }
          switch (evt.keyCode) {
            case 191:
              return $(".search-query:visible:first").focus();
            case 77:
              $('[data-toggle="offcanvas"]:first').click();
              return $('#sidebar:visible .list-group-item:first').focus();
            case 78:
              return $('[data-toggle="notification-center"]:first').click();
            case 27:
              if ($('#notification-center:visible')) {
                $('#notification-center').modal('hide');
              }
              return $('.sidebar-offcanvas').removeClass('active');
          }
        });
      };
      setupOffCanvas = function() {
        return $('[data-toggle="offcanvas"]').click(function() {
          return $('.sidebar-offcanvas').toggleClass('active');
        });
      };
      writeMenu = function(user) {
        var mo;
        $('#sidebar-loading').remove();
        mo = ChainNavPanel.MenuBuilder().createMenuObject(user);
        return ChainNavPanel.MenuWriter().writeMenu($("#sidebar"), mo);
      };
      setupHomepageModal = function() {
        $("#set-homepage-btn").click(function(evt) {
          return $.post("/users/set_homepage", {
            homepage: $(location).attr("href")
          });
        });
        return $('#nav-set-homepage').click(function(evt) {
          evt.preventDefault();
          return $('#homepage-modal').modal('show');
        });
      };
      setupSupportRequestModal = function() {
        var generateAlert;
        generateAlert = function(ticketNum) {
          return function() {
            return alert("Your ticket number is " + ticketNum + ".");
          };
        };
        $("#submit-support-request-btn").click(function(evt) {
          var button, msg, notice, prompt;
          button = $(evt.target);
          notice = $('#request-alert');
          prompt = $('#request-prompt');
          msg = $('#support-request-body').val();
          if (msg === '') {
            prompt.css("display", "inline");
            return;
          } else {
            button.attr('disabled', true);
            prompt.css("display", "none");
            notice.css("display", "inline");
          }
          return $.ajax({
            type: "POST",
            url: "/api/v1/support_requests",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json"
            },
            data: JSON.stringify({
              "support_request": {
                "body": msg
              }
            }),
            success: function(data) {
              var delayedAlert, ticket;
              notice.css("display", "none");
              button.attr('disabled', false);
              $('#support-request-modal').modal('hide');
              ticket = data["support_request_response"]["ticket_number"];
              delayedAlert = generateAlert(ticket);
              return window.setTimeout(delayedAlert, 0);
            }
          });
        });
        return $('#nav-support').click(function(evt) {
          evt.preventDefault();
          return $('#support-request-modal').modal('show');
        });
      };
      initNotificationCenter = function(callback) {
        return callback($('#notification-center-wrapper'));
      };
      $(elementToReplace).after(htmlWrapper['src/html/nav_panel.html']);
      $(elementToReplace).remove();
      registerHotKeys();
      userPromise.then(function(user) {
        return writeMenu(user);
      });
      setupOffCanvas();
      setupHomepageModal();
      setupSupportRequestModal();
      if (notificationCenterCallback) {
        return initNotificationCenter(notificationCenterCallback);
      }
    }
  };

}).call(this);

var ChainNavPanelHtml = ChainNavPanelHtml || {};
ChainNavPanelHtml["src/html/nav_panel.html"] = '<div id=\'chain-nav-panel\'>\n  <form class=\'form-inline form visible-xs\' role=\'search\' action=\'/quick_search\' method=\'GET\' id=\'mini-qs\'>\n    <div class="container-fluid" id=\'mini-qs-container\'>\n      <div class="row">\n        <div class="col-xs-11">\n          <input type=\'text\' class=\'search-query form-control\' placeholder=\'Quick Search\' data-toggle=\'tooltip\' title=\'press / to jump here\' name=\'v\' />\n        </div>\n        <div class=\'col-xs-1\'>\n          <a href=\'#\' onclick="$(\'#mini-qs\').submit(); return false;">\n            <i class=\'fa fa-search\'></i>\n          </a>\n        </div>\n      </div>\n    </div>\n  </form>\n  <div class=\'navbar\' role=\'navigation\' id=\'topnav\'>\n    <ul class="nav navbar-nav navbar-left pull-left" style=\'margin-left:3px;\'>\n      <li>\n        <button id=\'btn-left-toggle\' class=\'navbar-toggle\' data-toggle="offcanvas" title="shortcut key: m">\n          <span class="sr-only">Toggle navigation</span>\n          <span class="icon-bar"></span>\n          <span class="icon-bar"></span>\n          <span class="icon-bar"></span>\n        </button>\n      </li>\n    </ul>\n    <ul class="nav navbar-nav navbar-right pull-right"  style=\'margin-right:3px;\'>\n      <li id=\'notification-center-wrapper\'>\n      </li>\n    </ul>\n    <form class=\'navbar-form hidden-xs\' role=\'search\' action=\'/quick_search\' method=\'GET\' id=\'quicksearch\'>\n      <div class=\'form-group\'>\n        <input type=\'text\' class=\'search-query form-control\' placeholder=\'enter search term\' data-toggle=\'tooltip\' title=\'shortcut key: /\' name=\'v\' id=\'quick_search_input\' />\n        &nbsp;\n        <a href=\'#\' onclick="$(\'#quicksearch\').submit(); return false;">\n          <i class=\'fa fa-search\'></i>\n        </a>\n      </div>\n    </form>\n  </div>\n  <div class="sidebar-offcanvas panel-group" id="sidebar">\n    <a href=\'/\' title=\'Home\' class=\'list-group-item\'>Home</a>\n    <div id=\'sidebar-loading\'>\n      Please wait while your personalized menu is generated.\n    </div>\n  </div>\n</div>\n<div class="modal fade" id="homepage-modal">\n  <div class="modal-dialog">\n    <div class="modal-content">\n      <div class="modal-header"><h4 class="modal-title">Set Homepage To Current Page</h4></div>\n      <div class="modal-body">\n        <p>Click "OK" to make this page the first one you see when you log in to VFI Track.</p>\n        <p>You may also access your homepage at any time by clicking the Home link on the navigation bar.</p>\n      </div>\n      <div class="modal-footer">\n        <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>\n        <button type="button" class="btn btn-primary" data-dismiss="modal" id="set-homepage-btn">OK</button>\n      </div>\n    </div>\n  </div>\n</div>\n<div class="modal fade" id="support-request-modal">\n  <div class="modal-dialog">  \n    <div class="modal-content">\n      <div class="modal-header"><h4 class="modal-title">Request Support</h4></div>\n      <div class="modal-body row">\n        <div class="col-xs-12"> \n          <p>Send A Message:</p>\n          <textarea class=\'form-control\' id="support-request-body" autofocus=true rows=4></textarea>\n          <br>\n          <div class="alert alert-info col-xs-12" id="request-alert" style="display:none;">\n            Your request is being submitted.\n          </div>\n          <div class="alert alert-danger col-xs-12" id="request-prompt" style="display:none;">\n            You must enter a message first.\n          </div>\n        </div>\n      </div>\n      <div class="modal-footer">\n        <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>\n        <button type="button" class="btn btn-primary" id="submit-support-request-btn">OK</button>\n      </div>\n    </div>\n  </div>\n</div>\n<div class="modal fade" id="notification-center">\n  <div class="modal-dialog modal-max-width">\n    <div class="modal-content">\n      <div class="modal-header text-center">\n        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>\n        <div class="btn-group">\n          <button type="button" class="btn btn-default" notification-center-toggle-target=\'messages\'>Messages</button>\n          <button type="button" class="btn btn-default" notification-center-toggle-target=\'manuals\'>Manuals</button>\n        </div>\n      </div>\n      <div class="modal-body" id=\'notification-center-body\'>\n        <div notification-center-pane=\'messages\' content-url=\'/messages\'></div>\n        <div notification-center-pane=\'manuals\' content-url=\'/user_manuals/for_referer\'></div>\n      </div>\n    </div>\n  </div>\n</div>\n';

(function() {
  ChainNavPanel.MenuBuilder = function() {
    var addBrokerInvoiceMenu, addDrawbackMenu, addEntryMenu, addMoreMenu, addOrderMenu, addProductMenu, addSecurityFilingMenu, addShipmentMenu, addSurveyMenu, addTradeLaneMenu, addVendorMenu, addVfiInvoiceMenu, makeItem, makeItemIf, makeMenuIf;
    makeItemIf = function(bool, itemArray, id, label, url) {
      if (bool) {
        return itemArray.push(makeItem(id, label, url));
      }
    };
    makeItem = function(id, label, url) {
      return {
        label: label,
        url: url,
        id: "nav-" + id
      };
    };
    makeMenuIf = function(categories, id, label, items) {
      if (items && items.length > 0) {
        return categories.push({
          id: id,
          label: label,
          items: items
        });
      }
    };
    addOrderMenu = function(categories, user) {
      var items;
      items = [];
      makeItemIf(user.permissions.view_orders, items, 'order-search', 'Search', '/orders?force_search=true');
      makeItemIf(user.permissions.edit_orders, items, 'order-new', 'New', '/orders/new');
      makeItemIf(user.permissions.view_vendor_portal, items, 'vendor-portal', 'Vendor Portal', '/vendor_portal');
      return makeMenuIf(categories, 'nav-cat-order', 'Order', items);
    };
    addProductMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_products, items, 'product-search', 'Search', '/products?force_search=true');
      makeItemIf(u.permissions.edit_products, items, 'product-new', 'New', '/products/new');
      makeItemIf(u.permissions.view_official_tariffs, items, 'official-tariff-search', 'Search Tariffs', '/official_tariffs?force_search=true');
      makeItemIf(u.permissions.view_official_tariffs, items, 'official-tariff-browse', 'Browse Tariffs', '/hts');
      return makeMenuIf(cat, 'nav-cat-product', 'Product', items);
    };
    addShipmentMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_shipments, items, 'shipment-search', 'Search', '/shipments?force_search=true');
      makeItemIf(u.permissions.edit_shipments, items, 'shipment-new', 'New', '/shipments/new');
      return makeMenuIf(cat, 'nav-cat-shipment', 'Shipment', items);
    };
    addSecurityFilingMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_security_filings, items, 'isf-search', 'Search', '/security_filings?force_search=true');
      return makeMenuIf(cat, 'nav-cat-isf', 'Security Filing', items);
    };
    addEntryMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_entries, items, 'entry-sum-ca', 'Browse - CA', '/entries/activity_summary/ca');
      makeItemIf(u.permissions.view_entries, items, 'entry-sum-ca', 'Browse - US', '/entries/activity_summary/us');
      makeItemIf(u.permissions.view_entries, items, 'entry-search', 'Search', '/entries?force_search=true');
      makeItemIf(u.permissions.view_entries, items, 'entry-snapshot', 'Snapshot', '/entries/bi');
      return makeMenuIf(cat, 'nav-cat-entry', 'Entry', items);
    };
    addBrokerInvoiceMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_broker_invoices, items, 'brok-inv-search', 'Search', '/broker_invoices?force_search=true');
      makeItemIf(u.permissions.view_summary_statements, items, 'brok-inv-stmnt-search', 'Summary Statements', '/summary_statements');
      makeItemIf(u.permissions.edit_summary_statements, items, 'brok-inv-stmnt-new', 'New Statement', '/summary_statements/new');
      return makeMenuIf(cat, 'nav-cat-brok-inv', 'Broker Invoice', items);
    };
    addVfiInvoiceMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_vfi_invoices, items, 'vfi-inv-search', 'Search', '/vfi_invoices?force_search=true');
      return makeMenuIf(cat, 'nav-cat-vfi-inv', 'VFI Invoice', items);
    };
    addDrawbackMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_drawback, items, 'drawback-search', 'Search', '/drawback_claims?force_search=true');
      makeItemIf(u.permissions.edit_drawback, items, 'drawback-new', 'New', '/drawback_claims/new');
      makeItemIf(u.permissions.upload_drawback, items, 'drawback-upload', 'Upload', '/drawback_upload_files');
      return makeMenuIf(cat, 'nav-cat-drawback', 'Drawback', items);
    };
    addSurveyMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_survey_responses, items, 'survey-edit', 'View', '/survey_responses');
      makeItemIf(u.permissions.view_surveys, items, 'survey-view', 'Edit', '/surveys');
      return makeMenuIf(cat, 'nav-cat-survey', 'Survey', items);
    };
    addVendorMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_vendors, items, 'vendor-view', 'Search', '/vendors?force_search=true');
      makeItemIf(u.permissions.view_products && u.permissions.view_vendors, items, 'prod-ven-assignment-view', 'Vendor/Product Search', '/product_vendor_assignments?force_search=true');
      makeItemIf(u.permissions.create_vendors, items, 'vendor-new', 'New', '/vendors/new');
      return makeMenuIf(cat, 'nav-cat-vendor', 'Vendor', items);
    };
    addTradeLaneMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_trade_lanes, items, 'trade-lane-view', 'View', '/trade_lanes');
      makeItemIf(u.permissions.edit_trade_lanes, items, 'trade-lane-new', 'New', '/trade_lanes#/new');
      return makeMenuIf(cat, 'nav-cat-trade-lane', 'Trade Lane', items);
    };
    addMoreMenu = function(categories, user) {
      var items;
      items = [];
      items.push(makeItem('account', 'Account', '/me'));
      items.push(makeItem('custom-features', 'Custom Features', '/custom_features'));
      items.push(makeItem('dashboard', 'Dashboard', '/dashboard_widgets'));
      items.push(makeItem('reports', 'Reports', '/report_results'));
      items.push(makeItem('support', 'Support', '#'));
      items.push(makeItem('tools', 'Tools', '/tools'));
      items.push(makeItem('uploads', 'Uploads', '/imported_files'));
      items.push(makeItem('set-homepage', 'Set Homepage', '#'));
      items.push(makeItem('log-out', 'Log Out', '/logout'));
      return categories.push({
        id: 'nav-cat-more',
        label: 'more...',
        items: items
      });
    };
    return {
      createMenuObject: function(user) {
        var categories;
        categories = [];
        addProductMenu(categories, user);
        addOrderMenu(categories, user);
        addShipmentMenu(categories, user);
        addSecurityFilingMenu(categories, user);
        addEntryMenu(categories, user);
        addBrokerInvoiceMenu(categories, user);
        addVfiInvoiceMenu(categories, user);
        addDrawbackMenu(categories, user);
        addSurveyMenu(categories, user);
        addVendorMenu(categories, user);
        addTradeLaneMenu(categories, user);
        addMoreMenu(categories, user);
        return {
          categories: categories
        };
      }
    };
  };

}).call(this);

(function() {
  ChainNavPanel.MenuWriter = function() {
    return {
      writeMenu: function(wrapper, menuObj) {
        var cat, html, i, itm, j, len, len1, navTarget, ref, ref1;
        html = "";
        ref = menuObj.categories;
        for (i = 0, len = ref.length; i < len; i++) {
          cat = ref[i];
          navTarget = '#' + cat.id;
          html = html + "<div class='panel'>";
          html = html + "<div class='panel-heading'><h3 class='panel-title' data-toggle='collapse' data-target='" + navTarget + "'><a href='javascript:void(0)'>" + cat.label + "</a></h3></div><div class='panel-collapse collapse' id='" + cat.id + "'><div class='list-group'>";
          ref1 = cat.items;
          for (j = 0, len1 = ref1.length; j < len1; j++) {
            itm = ref1[j];
            html = html + "<a href='" + itm.url + "' class='list-group-item' id='" + itm.id + "'>" + itm.label + "</a>";
          }
          html = html + "</div></div></div>";
        }
        return wrapper.append(html);
      }
    };
  };

}).call(this);

(function() {
  var root;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  root.ChainNotificationCenter = {
    getMessageCount: function(url) {
      return $.getJSON(url, function(data) {
        if (data > 0) {
          return $('.message_envelope').each(function() {
            return $(this).html('' + data).addClass('messages');
          });
        } else {
          return $('.message_envelope').each(function() {
            return $(this).html('').removeClass('messages');
          });
        }
      });
    },
    initialize: function(user_id, pollingSeconds) {
      this.url = '/messages/message_count?user_id=' + user_id;
      return $(document).ready((function(_this) {
        return function() {
          _this.initNotificationCenter();
          _this.getMessageCount(_this.url);
          if (pollingSeconds > 0) {
            return _this.startPolling(pollingSeconds);
          }
        };
      })(this));
    },
    initNotificationCenter: function() {
      $('[data-toggle="notification-center"]').click(function() {
        return ChainNotificationCenter.toggleNotificationCenter();
      });
      $('[notification-center-toggle-target]').on('click', function() {
        return ChainNotificationCenter.showNotificationCenterPane($(this).attr('notification-center-toggle-target'));
      });
      $('#notification-center').on('click', '.delete-message-btn', function(evt) {
        var msgId;
        msgId = $(this).attr('message-id');
        evt.preventDefault();
        if (window.confirm('Are you sure you want to delete this message?')) {
          return $.ajax({
            url: '/messages/' + msgId,
            type: "post",
            data: {
              "_method": "delete"
            },
            success: function() {
              return $('#message-panel-' + msgId).fadeOut();
            }
          });
        }
      });
      $('#notification-center').on('click', '.show-time-btn', function(evt) {
        var t;
        t = $(this);
        if (t.html() === t.attr('title')) {
          return t.html("<span class='glyphicon glyphicon-time'></span>");
        } else {
          return t.html(t.attr('title'));
        }
      });
      $('#notification-center').click(function(event) {
        if (event.target === this) {
          return ChainNotificationCenter.hideNotificationCenter();
        }
      });
      $('#notification-center').on('show.bs.collapse', '.panel-collapse', function(event) {
        var id, panel, t;
        t = event.target;
        id = $(t).attr('message-id');
        panel = $('#message-panel-' + id);
        panel.find('.message-read-icon').removeClass('glyphicon-chevron-right').addClass('glyphicon-chevron-down');
        if (panel.hasClass('unread')) {
          panel.addClass('read').removeClass('unread');
          return $.get('/messages/' + id + '/read', function() {
            return ChainNotificationCenter.getMessageCount(ChainNotificationCenter.pollingUrl());
          });
        }
      });
      $('#notification-center').on('hide.bs.collapse', '.panel-collapse', function(event) {
        var id, t;
        t = event.target;
        id = $(t).attr('message-id');
        return $('#message-panel-' + id + ' .message-read-icon').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-right');
      });
      $('#notification-center').on('click', '.notification-mark-all-read', function(event) {
        return $.ajax({
          url: '/messages/read_all',
          success: function() {
            $('#notification-center').find('.unread').each(function() {
              return $(this).removeClass('unread').addClass('read');
            });
            return ChainNotificationCenter.getMessageCount(ChainNotificationCenter.pollingUrl());
          }
        });
      });
      return $('#notification-center').on('chain:notification-load', '[notification-center-pane="messages"]', function() {
        return $('[notification-center-pane="messages"] .message-body a').addClass('btn').addClass('btn-xs').addClass('btn-primary');
      });
    },
    pollingUrl: function() {
      return this.url;
    },
    startPolling: function(pollingSeconds) {
      if (!((this.intervalRegistration != null) || pollingSeconds <= 0)) {
        return this.intervalRegistration = setInterval((function(_this) {
          return function() {
            return _this.getMessageCount(_this.url);
          };
        })(this), pollingSeconds * 1000);
      }
    },
    stopPolling: function() {
      var reg;
      if (this.intervalRegistration != null) {
        reg = this.intervalRegistration;
        this.intervalRegistration = null;
        return clearInterval(reg);
      }
    },
    toggleNotificationCenter: function() {
      if ($("#notification-center").is(':visible')) {
        return ChainNotificationCenter.hideNotificationCenter();
      } else {
        return ChainNotificationCenter.showNotificationCenter();
      }
    },
    showNotificationCenter: function() {
      $("#notification-center").modal('show');
      return ChainNotificationCenter.showNotificationCenterPane('messages');
    },
    showNotificationCenterPane: function(target) {
      var pane;
      $("[notification-center-pane]").hide();
      $("[notification-center-toggle-target]").removeClass('btn-primary').addClass('btn-default');
      $("[notification-center-toggle-target='" + target + "']").removeClass('btn-default').addClass('btn-primary');
      pane = $("[notification-center-pane='" + target + "']");
      pane.html('<div class="loader"></div>');
      pane.show();
      return $.ajax({
        url: pane.attr('content-url'),
        data: {
          nolayout: 'true'
        },
        success: function(data) {
          var extraTrigger;
          extraTrigger = pane.attr('data-load-trigger');
          pane.html(data);
          pane.trigger('chain:notification-load');
          if (extraTrigger) {
            return pane.trigger(extraTrigger);
          }
        },
        error: function() {
          return pane.html("<div class='alert alert-danger'>We're sorry, an error occurred while trying to load this information.</div>");
        }
      });
    },
    hideNotificationCenter: function() {
      return $("#notification-center").modal('hide');
    }
  };

}).call(this);
