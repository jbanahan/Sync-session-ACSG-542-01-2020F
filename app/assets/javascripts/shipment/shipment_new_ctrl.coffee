
angular.module('ShipmentApp').controller 'ShipmentNewCtrl', ['$scope','shipmentSvc','$state',($scope,shipmentSvc,$state) ->
  loadImporters = ->
    $scope.importers = undefined
    shipmentSvc.getImporters().success((data) ->
      $scope.importers = data.importers
    )

  $scope.shp = {}

  $scope.save = (shipment) ->
    $scope.importers = undefined #reset loading flag
    shipmentSvc.saveShipment(shipment).then ((resp) ->
      shipmentSvc.getShipment(resp.data.shipment.id,true).then ->
        $state.go('show',{shipmentId: resp.data.shipment.id})
    ),((resp) ->
      loadImporters()
    )


  loadImporters()
]