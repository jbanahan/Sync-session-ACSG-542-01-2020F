angular.module('ShipmentApp').controller 'ShipmentBookingCtrl', ['shipmentSvc','$state','$timeout',(shipmentSvc, $state, $timeout) ->
  new class ShipmentBookingCtrl
    constructor: ->
      shipmentSvc.getShipment($state.params.shipmentId).then (resp) =>
        @bookingTypes = resp.data.shipment.permissions.enabled_booking_types

    lines: [{}]
    bookingTypes:[]

    chooseBookingType: (panelName) ->
      $('[data-container-id]').hide()
      $("[data-container-id='#{panelName}'").show()
      return false

    isEnabled: (name) =>
      name in @bookingTypes

    addLine: =>
      @lines.push {}
      $timeout -> $('angucomplete-alt input:visible').last().focus()
      return true

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

    saveButtonEnabled: =>
      @lines[0] && Object.keys(@lines[0]).filter((key)-> key != '$$hashKey').length > 0

    saveLines: =>
      flattenProducts = (lines) ->
        lines.forEach (line) ->
          if line.product
            product = line.product.originalObject
            line.bkln_prod_id = product.id
            line.bkln_pname = product.name
            line.bkln_puid = product.unique_identifier
            delete line.product

      flattenOrders = (lines) ->
        lines.forEach (line) ->
          if line.order
            line.bkln_order_id = line.order.originalObject.id
            delete line.order

      linesToSave = @lines.filter (line) -> if line.bkln_order_line_id and line.bkln_quantity == 0 then false else true
      flattenProducts linesToSave
      flattenOrders linesToSave
      shipmentId = $state.params.shipmentId
      shipmentSvc.saveBookingLines(linesToSave, shipmentId).then @cancel

    cancel: =>
      @lines.splice 0, @lines.length
      $state.go('show', {shipmentId: $state.params.shipmentId})
]