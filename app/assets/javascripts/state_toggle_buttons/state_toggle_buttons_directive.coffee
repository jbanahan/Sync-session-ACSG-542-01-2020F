@app = angular.module('ChainComponents')

@app.controller 'StateToggleButtonsCtrl', ['stateToggleButtonSvc','$scope','$element','$compile', (stateToggleButtonSvc,$scope,$element,$compile) ->

  $scope.showStateToggles = ->
    modalEl = $('#state-toggle-buttons-modal')
    if modalEl.length == 0
      modalText = $compile('<div class="modal" id="state-toggle-buttons-modal"><div class="modal-dialog"><div class="modal-content"><div class="modal-header"><h4 class="modal-title">Toggles</h4><button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button></div><div class="modal-body">
        <chain-loading-wrapper loading-flag="{{loading}}"><div ng-repeat="b in toggleButtons track by b.id"><state-toggle-item button-data="b"></state-toggle-item></div></chain-loading-wrapper>
        </div><div class="modal-footer"><button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button></div></div></div></div>')($scope)
      $('body').append(modalText) #appending to body so it doesn't get stuck in any containers
      modalEl = $('#state-toggle-buttons-modal')

    modalEl.modal 'show'

    $scope.loading = 'loading'

    stateToggleButtonSvc.getButtons($scope.moduleType,$scope.objectId).then (resp) ->
      $scope.toggleButtons = resp.state_toggle_buttons
      $scope.loading = null

    return null

  $scope.$on 'chain:state-toggle-change:start', ->
    $scope.loading = 'loading'

  $scope.$on 'chain:state-toggle-change:finish', ->
    $scope.toggleButtons = null
    $('#state-toggle-buttons-modal').modal 'hide'
    $scope.loading = null


    
]
@app.controller 'StateToggleItemCtrl', ['stateToggleButtonSvc','$scope', (stateToggleButtonSvc,$scope) ->
  $scope.toggleItem = ->
    $scope.$emit('chain:state-toggle-change:start')
    return stateToggleButtonSvc.toggleButton($scope.buttonData).then (data) ->
      $scope.$emit('chain:state-toggle-change:finish')
      return data

]

@app.directive 'stateToggleButtons', ->
  {
    restrict: 'E'
    scope: {
      'moduleType': '@'
      'objectId': '@'
    }
    replace: true
    template: "<button class='btn btn-secondary' ng-click='showStateToggles()'><i class='fa fa-th-list'></i></button>"
    controller: 'StateToggleButtonsCtrl'
  }

@app.directive 'stateToggleItem', ->
  {
    restrict: 'E'
    scope: {
      buttonData: '='
    }
    template: "<button class='btn btn-secondary btn-block' ng-click='toggleItem()'>{{buttonData.button_text}}</button>"
    controller: 'StateToggleItemCtrl'
  }
