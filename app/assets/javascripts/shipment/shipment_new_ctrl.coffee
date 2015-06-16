
angular.module('ShipmentApp').controller 'ShipmentNewCtrl', ['$scope','shipmentSvc','$state',($scope,shipmentSvc,$state) ->
  loadParties = ->
    $scope.parties = undefined
    shipmentSvc.getParties().success((data) ->
      $scope.parties = data
    )

  $scope.shp = {}

  $scope.save = (shipment) ->
    $scope.parties = undefined #reset loading flag
    shipmentSvc.saveShipment(shipment).then ((resp) ->
      shipmentSvc.getShipment(resp.data.shipment.id,true).then ->
        $state.go('show',{shipmentId: resp.data.shipment.id})
    ),((resp) ->
      loadParties()
    )


  loadParties()
]