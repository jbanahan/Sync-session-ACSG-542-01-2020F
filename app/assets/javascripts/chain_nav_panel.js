(function() {
  var root;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  root.ChainNavPanel = {
    write: function(htmlWrapper, elementToReplace, userPromise, notificationCenterCallback) {
      var initNotificationCenter, registerHotKeys, setupHomepageModal, setupOffCanvas, writeMenu;
      registerHotKeys = function() {
        return $(document).on('keyup', null, '/', function() {
          return $(".search-query:visible:first").focus();
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
      if (notificationCenterCallback) {
        return initNotificationCenter(notificationCenterCallback);
      }
    }
  };

}).call(this);

var ChainNavPanelHtml = ChainNavPanelHtml || {};
ChainNavPanelHtml["src/html/nav_panel.html"] = '<div id=\'chain-nav-panel\'>\n  <form class=\'form-inline form visible-xs\' role=\'search\' action=\'/quick_search\' method=\'GET\' id=\'mini-qs\'>\n    <div class="container-fluid" id=\'mini-qs-container\'>\n      <div class="row">\n        <div class="col-xs-11">\n          <input type=\'text\' class=\'search-query form-control\' placeholder=\'Quick Search\' data-toggle=\'tooltip\' title=\'press / to jump here\' name=\'v\' />\n        </div>\n        <div class=\'col-xs-1\'>\n          <a href=\'#\' onclick="$(\'#mini-qs\').submit(); return false;">\n            <span class=\'glyphicon glyphicon-search\'></span>\n          </a>\n        </div>\n      </div>\n    </div>\n  </form>\n  <div class=\'navbar\' role=\'navigation\' id=\'topnav\'>\n    <ul class="nav navbar-nav navbar-left pull-left" style=\'margin-left:3px;\'>\n      <li>\n        <button id=\'btn-left-toggle\' class=\'navbar-toggle\' data-toggle="offcanvas" title="shortcut key: m">\n          <span class="sr-only">Toggle navigation</span>\n          <span class="icon-bar"></span>\n          <span class="icon-bar"></span>\n          <span class="icon-bar"></span>\n        </button>\n      </li>\n    </ul>\n    <ul class="nav navbar-nav navbar-right pull-right"  style=\'margin-right:3px;\'>\n      <li id=\'notification-center-wrapper\'>\n        <!--<a href=\'#\' data-toggle=\'notification-center\' onclick="return false;" title=\'shortcut key: n\' class=\'message-envelope-wrapper\'>\n          <span class=\'glyphicon glyphicon-bell message_envelope\'></span>\n        </a>-->\n      </li>\n    </ul>\n    <form class=\'navbar-form hidden-xs\' role=\'search\' action=\'/quick_search\' method=\'GET\' id=\'quicksearch\'>\n      <div class=\'form-group\'>\n        <input type=\'text\' class=\'search-query form-control\' placeholder=\'enter search term\' data-toggle=\'tooltip\' title=\'shortcut key: /\' name=\'v\' id=\'quick_search_input\' />\n        &nbsp;\n        <a href=\'#\' onclick="$(\'#quicksearch\').submit(); return false;">\n          <span class=\'glyphicon glyphicon-search\'></span>\n        </a>\n      </div>\n    </form>\n  </div>\n  <div class="sidebar-offcanvas panel-group" id="sidebar">\n    <a href=\'/\' title=\'Home\' class=\'list-group-item\'>Home</a>\n    <div id=\'sidebar-loading\'>\n      Please wait while your personalized menu is generated.\n    </div>\n  </div>\n</div>\n<div class="modal fade" id="homepage-modal">\n  <div class="modal-dialog">\n    <div class="modal-content">\n      <div class="modal-header"><h4 class="modal-title">Set Homepage To Current Page</h4></div>\n      <div class="modal-body">\n        <p>Click "OK" to make this page the first one you see when you log in to VFI Track.</p>\n        <p>You may also access your homepage at any time by clicking the Home link on the navigation bar.</p>\n      </div>\n      <div class="modal-footer">\n        <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>\n        <button type="button" class="btn btn-primary" data-dismiss="modal" id="set-homepage-btn">OK</button>\n      </div>\n    </div>\n  </div>\n</div>';

(function() {
  ChainNavPanel.MenuBuilder = function() {
    var addBrokerInvoiceMenu, addDrawbackMenu, addEntryMenu, addMoreMenu, addOrderMenu, addProductMenu, addSecurityFilingMenu, addShipmentMenu, addSurveyMenu, addVendorMenu, makeItem, makeItemIf, makeMenuIf;
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
      makeItemIf(u.permissions.view_survey_responses, items, 'View', '/survey_responses');
      makeItemIf(u.permissions.view_surveys, items, 'Edit', '/surveys');
      return makeMenuIf(cat, 'nav-cat-survey', 'Survey', items);
    };
    addVendorMenu = function(cat, u) {
      var items;
      items = [];
      makeItemIf(u.permissions.view_vendors, items, 'View', '/vendors');
      makeItemIf(u.permissions.create_vendors, items, 'New', '/vendors/new');
      return makeMenuIf(cat, 'nav-cat-vendor', 'Vendor', items);
    };
    addMoreMenu = function(categories, user) {
      var items;
      items = [];
      items.push(makeItem('account', 'Account', '/me'));
      items.push(makeItem('dashboard', 'Dashboard', '/dashboard_widgets'));
      items.push(makeItem('reports', 'Reports', '/report_results'));
      items.push(makeItem('support', 'Support', '/support_tickets'));
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
        addDrawbackMenu(categories, user);
        addSurveyMenu(categories, user);
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
          html = html + "<div class='panel-heading'><h3 class='panel-title' data-toggle='collapse' data-target='" + navTarget + "'><a href='#' on-click='return false;'>" + cat.label + "</a></h3></div><div class='panel-collapse collapse' id='" + cat.id + "'><div class='list-group'>";
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
