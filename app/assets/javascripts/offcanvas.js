$(document).ready(function () {
  $('[data-toggle="offcanvas"]').click(function () {
    $('.row-offcanvas').toggleClass('active')
    $('.sidebar-offcanvas').toggleClass('active')
  });
  $('[data-toggle="mini-qs"]').click(function() {$("#mini-qs").toggle();});
  $('[data-toggle="notification-center"]').click(function() {
    Chain.toggleNotificationCenter();
  });
});