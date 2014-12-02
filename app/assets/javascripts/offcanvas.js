$(document).ready(function () {
  $('[data-toggle="offcanvas"]').click(function () {
    $('.sidebar-offcanvas').toggleClass('active')
  });
  $('[data-toggle="mini-qs"]').click(function() {$("#mini-qs").toggle();});
  $('[data-toggle="notification-center"]').click(function() {
    Chain.toggleNotificationCenter();
  });
});