window.DashTour = {
  showTour: () ->
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
      steps: [
        {
          element: "#dash-title"
          placement: 'bottom'
          title: 'Welcome to the Dashboard Tour'
          content: "You can use the arrow keys to move through the tour."
        }
        {
          title: "Your Dashboard"
          content: "Add previously created advanced searches from any module here for a quick view of your most important data. With no searches selected, you'll see the latest news from Vandegrift!"
        }
        {
          element: '#btn-modify'
          title: "Customize Your Dashboard"
          content: "You customize your Dashboard using created advanced searches from any module by clicking here."
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
