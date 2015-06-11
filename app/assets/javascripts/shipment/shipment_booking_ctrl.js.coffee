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

    onOrderSelected: (order) =>
      if order
        order = order.originalObject
        @lines.push
          bkln_order_id: order.id
          bkln_order_number: order.name

    onContainerSelected: (size) =>
      @lines.push
        bkln_container_size: size

    removeLine: (line) =>
      oldLine = (@lines.filter (ln) -> ln == line)[0]
      idx = @lines.indexOf oldLine
      @lines.splice idx,1

    loadAvailableOrders: =>
      shipment = {id:$state.params.shipmentId}
      shipmentSvc.getAvailableOrders(shipment).then (resp) =>
        @availableOrders = resp.data.available_orders

    getOrder: (id) =>
      shipmentSvc.getOrder(id).then (resp) =>
        @activeOrder = resp.data.order
        @lines = @activeOrder.order_lines.map (line) ->
          ordln_line_number: line.ordln_line_number
          ordln_puid: line.ordln_puid
          ordln_sku: line.ordln_sku
          bkln_order_line_id: line.id
          bkln_quantity: parseInt line.ordln_ordered_qty

    saveLines: =>
      linesToSave = @lines.filter (line) -> if line.bkln_order_line_id and line.bkln_quantity == 0 then false else true
      shipmentSvc.saveBookingLines(linesToSave, $state.params.shipmentId).then @cancel

    cancel: =>
      @lines.splice 0, @lines.length
      $state.go('show', {shipmentId: $state.params.shipmentId})
]