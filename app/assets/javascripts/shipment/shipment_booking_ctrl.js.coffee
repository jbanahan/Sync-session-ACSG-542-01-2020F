angular.module('ShipmentApp').controller 'ShipmentBookingCtrl',
  class ShipmentBookingCtrl
    chooseBookingType: (panelName) ->
      $('[data-container-id]').hide()
      $("[data-container-id='#{panelName}'").show()
    lines: []
    onProductSelected: (product) =>
      if product
        product = product.originalObject
        @lines.push
          bkln_prod_id: product.id
          bkln_pname: product.name
          bkln_puid: product.unique_identifier