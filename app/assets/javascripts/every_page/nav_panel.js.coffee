root = exports ? this
root.ChainNavPanel = {
  write : (userPromise,notificationCenterCallback) ->
    registerHotKeys = ->
      $(document).on 'keydown', (evt) ->
        return if $(evt.target).is(':input')
        switch evt.keyCode
          when 27 # esc
            $('#notification-center').modal('hide') if $('#notification-center:visible')
            $('.sidebar-offcanvas').removeClass('active')
          when 77 # m
            $('[data-toggle="offcanvas"]:first').click()
            $('#sidebar:visible .list-group-item:first').focus()
          when 78 # n
            $('[data-toggle="notification-center"]:first').click()
          when 85 # u
            $('#user_menu').click()
          when 191 # /
            evt.preventDefault()
            $(".search-query:visible:first").focus()

    MenuBuilder = () ->
      makeItemIf = (bool, itemArray, id, label, url) ->
        itemArray.push makeItem(id, label,url) if bool

      makeItem = (id, label, url) ->
        {label:label, url: url, id: "nav-"+id}

      makeMenuIf = (categories, id, label, items) ->
        if items && items.length > 0
          categories.push {
            id: id
            label: label
            items: items
          }

      addOrderMenu = (categories, user) ->
        items = []
        makeItemIf(user.permissions.edit_orders,items,'order-new','New','/orders/new')
        makeItemIf(user.permissions.view_orders,items,'order-search','Search','/orders?force_search=true')
        makeItemIf(user.permissions.view_vendor_portal,items,'vendor-portal','Vendor Portal','/vendor_portal')
        makeMenuIf(categories, 'nav-cat-order', 'Order', items)

      addAnalyticsMenu = (cat, user) ->
        items =[]
        makeItemIf(user.permissions.view_entries,items,'entry-sum-ca','Insights - CA','/entries/activity_summary/ca')
        makeItemIf(user.permissions.view_entries,items,'entry-sum-ca','Insights - US','/entries/activity_summary/us')
        items.push makeItem('reports', 'Reports', '/report_results')
        makeMenuIf(cat,'nav-cat-analytics','Analytics',items)

      addProductMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.edit_products,items,'product-new','New','/products/new')
        makeItemIf(u.permissions.view_products,items,'product-search','Search','/products?force_search=true')
        makeItemIf(u.permissions.view_official_tariffs,items,'official-tariff-search','Search Tariffs','/official_tariffs?force_search=true')
        makeItemIf(u.permissions.view_official_tariffs,items,'official-tariff-browse','Browse Tariffs','/hts')
        makeMenuIf(cat,'nav-cat-product','Product',items)

      addShipmentMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_shipments,items,'shipment-search','Search','/shipments?force_search=true')
        makeItemIf(u.permissions.edit_shipments,items,'shipment-new','New','/shipments/new')
        makeMenuIf(cat,'nav-cat-shipment','Shipment',items)

      addSecurityFilingMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_security_filings,items,'isf-search','Search','/security_filings?force_search=true')
        makeMenuIf(cat,'nav-cat-isf','Security Filing',items)

      addEntryMenu = (cat, u) ->
        items = []        
        makeItemIf(u.permissions.view_entries,items,'entry-search','Search','/entries?force_search=true')
        makeMenuIf(cat,'nav-cat-entry','Entry',items)

      addInvoiceMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_commercial_invoices,items,'invoice-search','Search','/invoices?force_search=true')
        makeMenuIf(cat,'nav-cat-invoices','Customer Invoice',items)

      addBrokerInvoiceMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_broker_invoices,items,'brok-inv-search','Search','/broker_invoices?force_search=true')
        makeItemIf(u.permissions.view_summary_statements,items,'brok-inv-stmnt-search','Summary Statements','/summary_statements')
        makeItemIf(u.permissions.edit_summary_statements,items,'brok-inv-stmnt-new','New Statement','/summary_statements/new')
        makeMenuIf(cat,'nav-cat-brok-inv','Broker Invoice',items)

      addStatementsMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_statements,items,'daily-statement-search','Daily Statements','/daily_statements?force_search=true')
        makeItemIf(u.permissions.view_statements,items,'monthly-statment-search','Monthly Statements','/monthly_statements?force_search=true')
        makeMenuIf(cat,'nav-cat-customs-statements','Statements',items)

      addVfiInvoiceMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_vfi_invoices, items, 'vfi-inv-search', 'Search', '/vfi_invoices?force_search=true')
        makeMenuIf(cat, 'nav-cat-vfi-inv', 'VFI Invoice', items)

      addDrawbackMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_drawback,items,'drawback-search','Search','/drawback_claims?force_search=true')
        makeItemIf(u.permissions.edit_drawback,items,'drawback-new','New','/drawback_claims/new')
        makeItemIf(u.permissions.upload_drawback,items,'drawback-upload','Upload','/drawback_upload_files')
        makeMenuIf(cat,'nav-cat-drawback','Drawback',items)

      addSurveyMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_surveys,items,'survey-view','Edit','/surveys')
        makeItemIf(u.permissions.view_survey_responses,items,'survey-edit','View','/survey_responses')
        makeMenuIf(cat,'nav-cat-survey','Survey',items)

      addVendorMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_vendors,items,'vendor-view','Search','/vendors?force_search=true')
        makeItemIf(u.permissions.view_products && u.permissions.view_vendors,items,'prod-ven-assignment-view', 'Vendor/Product Search', '/product_vendor_assignments?force_search=true')
        makeItemIf(u.permissions.create_vendors,items,'vendor-new','New','/vendors/new')
        makeMenuIf(cat,'nav-cat-vendor','Vendor',items)

      addTradeLaneMenu = (cat, u) ->
        items = []
        makeItemIf(u.permissions.view_trade_lanes,items,'trade-lane-view','View','/trade_lanes')
        makeItemIf(u.permissions.edit_trade_lanes,items,'trade-lane-new','New','/trade_lanes#/new')
        makeMenuIf(cat,'nav-cat-trade-lane','Trade Lane',items)

      addToolsMenu = (cat, u) ->
        items = []
        items.push makeItem('custom-features','Custom Features','/custom_features')
        items.push makeItem('settings', 'Settings', '/settings')
        items.push makeItem('system-tools', 'System Tools', '/tools')
        items.push makeItem('mod-dash', 'Modify Dashboard', '/dashboard_widgets/edit')
        makeMenuIf(cat, 'nav-tools', 'Tools', items)

      return {
        createMenuObject: (user) ->
          categories = []

          addAnalyticsMenu(categories,user)
          addProductMenu(categories,user)
          addOrderMenu(categories,user)
          addShipmentMenu(categories,user)
          addSecurityFilingMenu(categories,user)
          addEntryMenu(categories,user)
          addBrokerInvoiceMenu(categories,user)
          addStatementsMenu(categories,user)
          addVfiInvoiceMenu(categories, user)
          addDrawbackMenu(categories,user)
          addSurveyMenu(categories,user)
          addVendorMenu(categories,user)
          addTradeLaneMenu(categories,user)
          addInvoiceMenu(categories,user)
          addToolsMenu(categories,user)

          return {categories:categories}
      }

    setupOffCanvas = ->
      $('[data-toggle="offcanvas"]').click ->
        $('.sidebar-offcanvas').toggleClass('active')

    MenuWriter = () ->
      return {
        writeMenu: (wrapper,menuObj) ->
          html = ""
          for cat in menuObj.categories
            navTarget = '#'+cat.id
            html = html + "<div class='card'>"
            html = html + "<div class='card-body py-2'><h6 class='card-title my-0' data-toggle='collapse' data-target='"+navTarget+"'><a href='javascript:void(0)' class='pm-0'>"+cat.label+"</a></h6></div><div class='collapse' id='"+cat.id+"'><div class='list-group'>"
            for itm in cat.items
              html = html + "<a href='"+itm.url+"' class='list-group-item' id='"+itm.id+"'>"+itm.label+"</a>"
            html = html + "</div></div></div>"
          wrapper.append(html)
      }

    writeMenu = (user) ->
      $('#sidebar-loading').remove()
      mo = MenuBuilder().createMenuObject(user)
      MenuWriter().writeMenu($("#sidebar"),mo)

    writeUserMenu = () -> 
      $('.user-menu-loading').remove() 
      UserMenuWriter().writeMenu($("#user_dropdown_menu"), false) 
      UserMenuWriter().writeMenu($("#user_mobile_dropdown_menu"), true)

    UserMenuWriter = () -> 
      return { 
        writeMenu: (wrapper, mobile) -> 
          html = "<a " + ( if mobile then "" else "id='user_menu'" )+" title='shortcut key: u' href='javascript:void(null);' class='nav-link dropdown-toggle pr-1' data-toggle='dropdown' aria-haspopup='true' aria-expanded='false'> 
            <i class='fa fa-user-circle-o fa-lg'></i><span class='caret'></span> 
          </a> 
          <div class='dropdown-menu dropdown-menu-right' aria-labelledby='user_dropdown_menu'>
            <a "+ ( if mobile then "" else "id='btn_account'" )+" class='dropdown-item' href='/me'>My Account</a> 
            <a "+ ( if mobile then "" else "id='btn_dashboard'" )+" class='dropdown-item' href='/dashboard_widgets'>My Dashboard</a> 
            <a "+ ( if mobile then "" else "id='uploads'" )+" class='dropdown-item' href='/imported_files'>My Uploads</a> 
            <a "+ ( if mobile then "" else "id='nav-set-homepage'" )+" class='dropdown-item' href='javascript:void(null);'>Set Homepage</a> 
            <a "+ ( if mobile then "" else "id='btn_user_manuals'" )+" class='dropdown-item' href='javascript:void(null);'>User Manuals</a> 
            <a "+ ( if mobile then "" else "id='nav-support'" )+" class='dropdown-item' href='javascript:void(null);'>Support</a>
            "+ ( if mobile then "" else "<button id='btn_menu_tour' class='dropdown-item' href='javascript:void(null);'>VFI Track Tour</button>" )+"
            <a "+ ( if mobile then "" else "id='btn_vandegrift_link'" )+" class='dropdown-item' href='https://www.vandegriftinc.com' target='_blank'>Vandegriftinc.com</a> 
            <div class='dropdown-divider'></div> 
            <a class='dropdown-item' href='/logout'>Log Out</a> 
          </div>" 
          wrapper.append(html) 
      }

    setupHomepageModal = ->
      $("#set-homepage-btn").click (evt) ->
        $.post("/users/set_homepage", {homepage: $(location).attr("href")})

      $('#nav-set-homepage').click (evt) ->
        evt.preventDefault()
        $('#homepage-modal').modal('show')

    setupSupportRequestModal = ->
      generateAlert = (ticketNum) ->
        ->
          alert "Your ticket number is #{ticketNum}."
      
      $("#submit-support-request-btn").click (evt) ->
        button = $(evt.target)
        notice = $('#request-alert')
        prompt = $('#request-prompt')

        msg = $('#support-request-body').val()
        if msg == ''
          prompt.css("display", "inline")
          return
        else
          button.attr('disabled', true)
          prompt.css("display", "none")
          notice.css("display", "inline")

        $.ajax(
          type: "POST"
          url: "/api/v1/support_requests"
          headers:
            Accept: "application/json"
            "Content-Type": "application/json" 
          data: JSON.stringify {"support_request": { "body": msg}}
          success: (data) ->
            notice.css("display", "none")
            button.attr('disabled', false)
            $('#support-request-modal').modal('hide')
            ticket = data["support_request_response"]["ticket_number"]
            delayedAlert = generateAlert(ticket)
            window.setTimeout(delayedAlert, 0);
      )

      $('#nav-support').click (evt) ->
        evt.preventDefault()
        $('#support-request-modal').modal('show')

    initNotificationCenter = (callback) ->
      callback($('#notification-center-wrapper'))

    showTour = ->
      # Prevent the next or previous button mouse click from closing menus for every tour
      $(document).on 'click', '.popover-navigation [data-role=next],.popover-navigation [data-role=prev]', (e) ->
        e.stopPropagation()
        return
        
      $("#btn_menu_tour").click (evt) ->
        VfiTour.showTour()

    showNavTour = ->
      $("#btn_nav_tour").click (evt) ->
        removebtn = () ->
          Chain.hideMessage('vfitrack_tour')
          if $('#btn_nav_tour').is(":visible")
            $("#btn_nav_tour").fadeOut("slow")

        VfiTour.showTour(removebtn)

    setupManualModal = ->
      $("#btn_user_manuals").click (evt) ->
        $("#notification-center").modal('show')
        root.ChainNotificationCenter.showNotificationCenterPane('manuals')

    setupDropdownAnimation = ->
      # Add slideDown animation to Bootstrap dropdown when expanding.
      $('.dropdown').on 'show.bs.dropdown', ->
        $(this).find('.dropdown-menu').first().stop(true, true).slideDown(120)
        return
      # Add slideUp animation to Bootstrap dropdown when collapsing.
      $('.dropdown').on 'hide.bs.dropdown', ->
        $(this).find('.dropdown-menu').first().stop(true, true).slideUp(120)
        return

    registerHotKeys()
    writeUserMenu()
    userPromise.then (user) ->
      writeMenu(user)
    setupOffCanvas()
    setupHomepageModal()
    setupSupportRequestModal()
    initNotificationCenter(notificationCenterCallback) if notificationCenterCallback
    setupManualModal()
    setupDropdownAnimation()
    showTour()
    showNavTour()
}
