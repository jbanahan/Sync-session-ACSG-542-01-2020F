describe 'stateToggleButtons', ->
  $compile = $rootScope = stateToggleButtonSvc = $controller = element = $scope = $q = null

  beforeEach(module('ChainComponents'))

  beforeEach(inject (_$compile_, _$rootScope_,_stateToggleButtonSvc_,_$controller_,_$q_,$templateCache) ->
    $templateCache.put('/partials/components/loading.html',"<div ng-transclude ng-hide='loadingFlag==\"loading\"'></div>")
    $compile = _$compile_
    $rootScope = _$rootScope_
    stateToggleButtonSvc = _stateToggleButtonSvc_
    $scope = $rootScope.$new()
    $q = _$q_
    $controller = _$controller_
  )

  afterEach ->
    $('#state-toggle-buttons-modal').remove()

  
  describe 'directive HTML',  ->
    it 'Replaces the element with the appropriate content', ->
      element = $compile("<state-toggle-buttons module-type='Orders' object-id='10'></state-toggle-buttons>")($scope)
      $scope.$digest()
      expect(element.attr('ng-click')).toEqual 'showStateToggles()'
      expect(element.prop('tagName')).toEqual 'BUTTON'

  describe 'showStateToggles', ->
    StateToggleButtonsCtrl = null
    beforeEach ->
      StateToggleButtonsCtrl = $controller('StateToggleButtonsCtrl',{$scope: $scope, stateToggleButtonSvc: stateToggleButtonSvc, $element:element, $compile: $compile})
      
    it 'should load buttons and insert modal', ->
      d = $q.defer()
      stbResp = {state_toggle_buttons:[
        {id:1,button_text:'btxt1',button_confirmation:'bconf1',core_module_path:'orders',base_object_id:10}
        {id:2,button_text:'btxt2',button_confirmation:'bconf2',core_module_path:'orders',base_object_id:10}
      ]}
      spyOn(stateToggleButtonSvc,'getButtons').andReturn(d.promise)

      $scope.showStateToggles()

      expect($('#state-toggle-buttons-modal').is(':visible')).toBeTruthy()
      expect($scope.loading).toEqual 'loading'

      d.resolve(stbResp)

      $scope.$apply()

      expect($scope.loading).toNotEqual 'loading'
      expect($scope.toggleButtons).toEqual stbResp.state_toggle_buttons

    it 'should set loading flag when "chain:state-toggle-change:start"', ->
      expect($scope.loading).toNotEqual 'loading'
      $rootScope.$broadcast('chain:state-toggle-change:start')
      expect($scope.loading).toEqual 'loading'

    it 'should clear togglebuttons, loading flag, and close modal when chain:state-toggle-change:finish', ->
      # SETUP ENVIRONMENT
      d = $q.defer()
      stbResp = {state_toggle_buttons:[
        {id:1,button_text:'btxt1',button_confirmation:'bconf1',core_module_path:'orders',base_object_id:10}
        {id:2,button_text:'btxt2',button_confirmation:'bconf2',core_module_path:'orders',base_object_id:10}
      ]}
      spyOn(stateToggleButtonSvc,'getButtons').andReturn(d.promise)

      $scope.showStateToggles()

      expect($('#state-toggle-buttons-modal').is(':visible')).toBeTruthy()
      expect($scope.loading).toEqual 'loading'

      d.resolve(stbResp)

      $scope.$apply()

      # ACTUAL TEST CODE
      $scope.$root.$broadcast('chain:state-toggle-change:finish')
      expect($('#state-toggle-buttons-modal').is(':visible')).toBeFalsy()
      expect($scope.loading).toBeNull()
      expect($scope.toggleButtons).toBeNull()



  describe 'StateToggleItem', ->

    it 'should toggle item', ->
      StateToggleItemCtrl = $controller('StateToggleItemCtrl',{$scope: $scope, stateToggleButtonSvc: stateToggleButtonSvc})
      resp = {ok:'ok'}
      d = $q.defer()
      spyOn(stateToggleButtonSvc,'toggleButton').andReturn(d.promise)

      toggleStartFired = false
      toggleCompleteFired = false
      $rootScope.$on 'chain:state-toggle-change:start', ->
        toggleStartFired = true
      $rootScope.$on 'chain:state-toggle-change:finish', ->
        toggleCompleteFired = true

      response = null
      $scope.toggleItem().then (httpResp) ->
        response = httpResp

      # since we've run the toggle but not resolved the $q, then the start
      # event should have been emitted, but the complete should not
      expect(toggleStartFired).toBeTruthy()
      expect(toggleCompleteFired).toBeFalsy()

      d.resolve(resp)

      $scope.$apply()

      expect(response).toEqual resp

      expect(toggleCompleteFired).toBeTruthy()