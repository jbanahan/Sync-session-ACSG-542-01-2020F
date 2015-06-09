angular.module('ShipmentApp').controller 'ShipmentBookingCtrl', (shipmentSvc, $state) ->
  new class ShipmentBookingCtrl
    lines: []

    chooseBookingType: (panelName) ->
      $('[data-container-id]').hide()
      $("[data-container-id='#{panelName}'").show()
      return false

    onProductSelected: (product) =>
      if product
        product = product.originalObject
        @lines.push
          bkln_prod_id: product.id
          bkln_pname: product.name
          bkln_puid: product.unique_identifier

    saveLines: =>
      shipmentSvc.saveBookingLines(@lines).then @cancel

    cancel: =>
      @lines.splice 0, @lines.length
      $state.go('show', {shipmentId: shipmentSvc.currentShipmentId()})
