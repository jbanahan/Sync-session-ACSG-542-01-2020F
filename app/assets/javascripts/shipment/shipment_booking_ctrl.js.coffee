angular.module('ShipmentApp').controller 'ShipmentBookingCtrl',
  class ShipmentBookingCtrl
    chooseBookingType: (panelName) ->
      $('[data-container-id]').hide()
      $("[data-container-id='#{panelName}'").show()