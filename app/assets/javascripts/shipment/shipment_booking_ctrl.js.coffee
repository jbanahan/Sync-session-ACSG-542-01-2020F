angular.module('ShipmentApp').controller 'ShipmentBookingCtrl', ['shipmentSvc','$state',(shipmentSvc, $state) ->
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


    removeLine: (line) =>
      oldLine = (@lines.filter (ln) -> ln == line)[0]
      idx = @lines.indexOf oldLine
      @lines.splice idx,1

    loadAvailableOrders: =>
      shipment = {id:$state.params.shipmentId}
      shipmentSvc.getAvailableOrders(shipment).then (resp) =>
        @availableOrders = resp.data.available_orders

    getOrder: (id)=>
      shipmentSvc.getOrder(id).then (resp) =>
        @activeOrder = resp.data.order

    saveLines: =>
      shipmentSvc.saveBookingLines(@lines).then @cancel

    cancel: =>
      @lines.splice 0, @lines.length
      $state.go('show', {shipmentId: $state.params.shipmentId})
]