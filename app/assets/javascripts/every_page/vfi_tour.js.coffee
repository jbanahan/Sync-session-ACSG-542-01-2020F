root = exports ? this
root.VfiTour = {
  showTour: (callback) ->

    openUserMenu= () ->
      promise = new Promise((resolve, reject) ->
        $('#user_menu').dropdown('toggle')
        i = 0
        checkOpen = setInterval((->
          if $('#user_dropdown_menu').hasClass('show')
            clearInterval checkOpen
            resolve()
            return
          else
            i++

          if i == 30
            clearInterval
            resolve()
            return

           ), 100)
        return
    )
      promise

    closeUserMenu= () ->
      promise = new Promise((resolve, reject) ->
        $('#user_menu').dropdown('toggle')
        i = 0
        checkOpen = setInterval((->
          unless $('#user_dropdown_menu').hasClass('show')
            clearInterval checkOpen
            resolve()
            return
          else
            i++

          if i == 30
            clearInterval
            resolve()
            return

           ), 100)
        return
    )
      promise

    openNavMenu= () ->
      promise = new Promise((resolve, reject) ->
        $('[data-toggle="offcanvas"]:first').click()
        i = 0
        checkOpen = setInterval((->
          if $('#sidebar').hasClass('active')
            clearInterval checkOpen
            resolve()
            return
          else
            i++

          if i == 30
            clearInterval
            resolve()
            return

           ), 100)
        return
    )
      promise

    closeNavMenu= () ->
      promise = new Promise((resolve, reject) ->
        $('[data-toggle="offcanvas"]:first').click()
        i = 0
        checkOpen = setInterval((->
          unless $('#sidebar').hasClass('active')
            clearInterval checkOpen
            resolve()
            return
          else
            i++

          if i == 30
            clearInterval
            resolve()
            return

           ), 100)
        return
    )
      promise

    openNavSubMenu= () ->
      promise = new Promise((resolve, reject) ->
        $('#nav-cat-entry').collapse('toggle')
        i = 0
        checkOpen = setInterval((->
          unless $('#nav-cat-entry').hasClass('show')
            clearInterval checkOpen
            resolve()
            return
          else
            i++

          if i == 30
            clearInterval
            resolve()
            return

           ), 100)
        return
    )
      promise

    closeNavSubMenu= () ->
      promise = new Promise((resolve, reject) ->
        $('#nav-cat-entry').collapse('toggle')
        i = 0
        checkOpen = setInterval((->
          unless $('#nav-cat-entry').hasClass('show')
            clearInterval checkOpen
            resolve()
            return
          else
            i++

          if i == 30
            clearInterval
            resolve()
            return

           ), 100)
        return
    )
      promise

    tour = new Tour(
      storage: false
      orphan: true
      template: "<div class='popover tour'>
          <div class='arrow'></div>
          <h3 class='popover-header'></h3>
          <div class='popover-body'></div>
          <div class='popover-navigation'>
            <div class='btn-group'>
              <button class='btn btn-sm btn-secondary' data-role='prev'><i class='fa fa-caret-left' aria-hidden='true'></i> Prev</button>
              <button id='tour_nxt_btn' class='btn btn-sm' data-role='next'>Next <i class='fa fa-caret-right' style='color: gold' aria-hidden='true'></i></button>
            </div>
            <button class='btn btn-sm btn-secondary' data-role='end'>End Tour</button>
          </div>
        </div>"
      onStart: () ->
        if ($('#notification-center').hasClass('show'))
          $('#notification_bell').click()
        if ($('#sidebar').hasClass('active'))
          closeNavMenu()
        if ($('#user_dropdown_menu').hasClass('show'))
          closeUserMenu()
      onEnd: () ->
        typeof callback == 'function' and callback()
        if ($('#notification-center').hasClass('show'))
          $('#notification_bell').click()
        if ($('#sidebar').hasClass('active'))
          closeNavMenu()
        if ($('#user_dropdown_menu').hasClass('show'))
          closeUserMenu()
      steps: [
        {
          title: 'Welcome to the Maersk Navigator Tour'
          content: "You can use the arrow keys to move back and forth through the tour."
        }
        {
          element: '#btn-left-toggle'
          title: "Navigate"
          content: "Navigate through the system using the menu here.<br /><br /> Use the 'm' key to open this menu."
          onShow: () ->
            unless ($('#sidebar').hasClass('active'))
              openNavMenu()
          onPrev: () ->
            if ($('#sidebar').hasClass('active'))
              closeNavMenu()
        }
        {
          element: '#sidebar'
          title: "Module Selection"
          content: "Select a module to display it's submenu."
          onShow: () ->
            unless ($('#sidebar').hasClass('active'))
              openNavMenu()
        }
        {
          element: 'div > #nav-entry-search'
          title: "Submenu Actions"
          content: "Select the action you would like to perform. In this example, you can select Search to view the Entry module Advanced Search."
          onShow: () ->
            unless ($('#sidebar').hasClass('active'))
              openNavMenu()
            unless ($('#nav-cat-entry').hasClass('show'))
              openNavSubMenu()

          onPrev: () ->
            if ($('#nav-cat-entry').hasClass('show'))
              closeNavSubMenu()

          onNext: () ->
            if ($('#nav-cat-entry').hasClass('show'))
              closeNavSubMenu()
            if ($('#sidebar').hasClass('active'))
              closeNavMenu()
        }
        {
          element: '.search-query:visible'
          title: "Quick Search"
          content: "If you already have a known value, such as a PO number or
          Bill of Lading, than you can find it with Quick Search. Just type it in here.
          <br /><br /><br />
          Use the '/' key to jump here.
          <br /><br />Pro tip: This is a great short cut to jump back up to the top
          of the page when you’ve scrolled all the way down to the bottom."
        }

        {
          element: "#btn_home"
          title: "Home Button"
          content: "Click this home button to take you back to your Maersk Navigator homepage."
        }
        {
          element: '#user_dropdown_menu'
          title: "Your User Menu"
          content: "The new user menu contains settings and information pertaining to your account and interaction with Maersk Navigator.<br /><br />Jump into this menu with the 'u' key."
          onNext: () ->
            unless $('#user_dropdown_menu').hasClass('show')
              openUserMenu()
        }
        {
          element: '#btn_account'
          title: 'Your Account'
          content: "Here is where you can change your settings such as timezone and your password."
          onShown: () ->
            unless $('#user_dropdown_menu').hasClass('show')
              openUserMenu()
          onPrev: () ->
            if $('#user_dropdown_menu').hasClass('show')
              closeUserMenu()
        }
        {
          element: '#btn_dashboard'
          title: 'Your Dashboard'
          content: 'This will take you back to your dashboard regardless of where you are in the application or whether you have changed your homepage.'
          onShow: () ->
            unless $('#user_dropdown_menu').hasClass('show')
              openUserMenu()
        }
        {
          element: '#uploads'
          title: 'Your Uploads'
          content: 'Check on the status of files you\'ve uploaded.'
          onShow: () ->
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
        }
        {
          element: '#nav-set-homepage'
          title: 'Setting your Homepage'
          content: "This changes the page you'll be taken to when clicking on the home
            button in the nav bar above and the default page you will see when visiting
            Maersk Navigator.<br /><br />You can use this if you want to always start at a specific screen
            in Maersk Navigator when you log in."
          onShow: () ->
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
        }
        {
          element: '#btn_user_manuals'
          title: 'User Manuals'
          content: 'Access manuals for using Maersk Navigator here.
            The manuals can also be found through the notification bell icon on the left
            side of the navigation bar.'
          onShow: () ->
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
        }
        {
          element: '#nav-support'
          title: 'Requesting support'
          content: 'Need some help with Maersk Navigator? Click here to ask our skilled support professionals for assistance.'
          onShow: () ->
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
        }
        {
          element: '#btn_menu_tour'
          title: "Maersk Navigator Tours"
          content: "You can launch this tour again from any screen."
          onShow: () ->
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
        }
        {
          element: '#btn_vandegrift_link'
          title: 'Visit Vandegrift Online'
          content: 'Check us out online! You can find our latest news, company contact information, and even job openings on Vandegriftinc.com.'
          onShow: () ->
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
          onNext: () ->
            if ($('#user_dropdown_menu').hasClass('show'))
              closeUserMenu()
        }
        {
          element: '#notification_bell'
          title: 'Notifications and Manuals'
          content: 'Here you will be given notice of any system messages, such as reports and searches that have been prepared for download. You’ll also find user manuals here.'
          onNext: () ->
            unless ($('#notification-center').hasClass('show'))
              $('#notification_bell').click()
          onPrev: () ->
            if ($('#notification-center').hasClass('show'))
              $('#notification_bell').click()
            unless ($('#user_dropdown_menu').hasClass('show'))
              openUserMenu()
        }
        {
          element: '#messages-settings-menu'
          title: 'Quick settings'
          content: 'You can mark all your system messages as read or have an email sent to you when you receive a new system message.'
          onShow: () ->
            unless ($('#notification-center').hasClass('show'))
              $('#notification_bell').click()
          onPrev: () ->
            if ($('#notification-center').hasClass('show'))
              $('#notification_bell').click()
        }
        {
          element: '#btn_messages_manuals'
          title: 'Messages and Manuals'
          content: "By default you'll find your messages below. Click Manuals to switch to your list of available user manuals."
          onShow: () ->
            unless ($('#notification-center').hasClass('show'))
              $('#notification_bell').click()
          onNext: () ->
            if ($('#notification-center').hasClass('show'))
              $('#notification_bell').click()
        }
        {
          title: 'Thank You for Using Maersk Navigator'
          content: 'This completes the Maersk Navigator tour.'
          template: "<div class='popover tour'>
        <div class='arrow'></div>
        <h3 class='popover-header'></h3>
        <div class='popover-body'></div>
        <div class='popover-navigation'>
          <div class='btn-group'>
            <button class='btn btn-sm btn-secondary' data-role='prev'><i class='fa fa-caret-left' aria-hidden='true'></i> Prev</button>
            <button id='tour_nxt_btn' class='btn btn-sm' data-role='next'>Next <i class='fa fa-caret-right' style='color: gold' aria-hidden='true'></i></button>
          </div>
          <button class='btn btn-sm btn-secondary' data-role='end'>Finish Tour</button>
        </div>
      </div>"
        }
      ]).init().restart()
}
