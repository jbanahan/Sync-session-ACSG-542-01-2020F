angular.module('ShipmentApp').controller 'ShipmentNewCtrl', ['$scope','shipmentSvc','$window',($scope,shipmentSvc,$window) ->
  loadImporters = ->
    $scope.importers = undefined
    shipmentSvc.getImporters().then((resp, status) ->
      $scope.importers = resp.data.importers
    )

  $scope.shp = {}

  $scope.save = (shipment) ->
    $scope.importers = undefined #reset loading flag
    shipmentSvc.saveShipment(shipment).then ((resp, status) ->
      $window.location.assign("/shipments/" + resp.data.shipment.id)
    ),((resp) ->
      loadImporters()
    )

  loadImporters()
]
