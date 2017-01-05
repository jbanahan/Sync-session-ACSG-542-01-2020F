describe 'StateToggleButtonApp', () ->
  beforeEach module('StateToggleButtonApp')

  describe 'service', () ->
    svc = http = null
    beforeEach inject(($httpBackend,stateToggleButtonMaintSvc) ->
      svc = stateToggleButtonMaintSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'loadButton', () ->
      it "loads", () ->
        returnVal = 
          button: "button"
          criteria: ["criteria"]
          sc_mfs: ["search model fields"] 
          user_mfs: ["user model fields"] 
          user_cdefs: ["user custom defs"] 
          date_mfs: ["date model fields"] 
          date_cdefs: ["date custom defs"]
        http.expectGET('/api/v1/admin/state_toggle_buttons/1/edit.json').respond returnVal
        promise = svc.loadButton(1)
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        http.flush()
        expect(resolvedPromise).toEqual returnVal

    describe 'updateButton', () ->
      it "executes PUT route", () ->
        returnVal = {'ok':'ok'}
        criteria = ['criteria']
        stb = {}
        http.expectPUT('/api/v1/admin/state_toggle_buttons/1', JSON.stringify({criteria: criteria, stb: stb})).respond returnVal
        promise = svc.updateButton(1, {criteria: criteria, stb: stb})
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        http.flush()
        expect(resolvedPromise).toEqual returnVal

  describe 'controller', () ->
    ctrl = svc = $scope = q = loc = null

    beforeEach inject(($rootScope,$controller,$location,$q,stateToggleButtonMaintSvc,chainSearchOperators) ->
      loc = $location
      $scope = $rootScope.$new()
      svc = stateToggleButtonMaintSvc
      ctrl = $controller('stateToggleButtonCtrl',{$scope:$scope})
      q = $q
    )

    describe 'get_id', () ->
      it "extracts id number from url", () ->
        url = "http://www.vfitrack.net/state_toggle_buttons/123/edit"
        expect($scope.getId(url)).toEqual '123'

    describe 'loadButton', () ->
      it "calls service's loadButton and assigns return values to scope", () ->
        stb = 
          module_type: "Order"
          user_attribute: "ord_closed_by"
          user_custom_definition_id: null
          date_attribute: "ord_closed_at"
          date_custom_definition_id: null
          permission_group_system_codes: "CODES"
          activate_text: "Activated!"
          activate_confirmation_text: "Activated?"
          deactivate_text: "Inactive"
          deactivate_confirmation_text: "Deactivated?"  
        
        data = 
          data:
            button:
              state_toggle_button: stb
            criteria: "criteria"
            sc_mfs: "search model fields"
            user_mfs: "user model fields"
            user_cdefs: "user custom defs"
            date_mfs: "date model fields"
            date_cdefs: "date custom defs"
              
        deferredLoad = q.defer()
        deferredLoad.resolve data
        spyOn(svc, 'loadButton').andReturn deferredLoad.promise
        $scope.loadButton(1)
        $scope.$apply()

        expect(svc.loadButton).toHaveBeenCalledWith(1)
        expect($scope.stb).toEqual stb
        expect($scope.searchCriterions).toEqual 'criteria'
        expect($scope.scMfs).toEqual 'search model fields'
        expect($scope.userMfs).toEqual 'user model fields'
        expect($scope.userCdefs).toEqual 'user custom defs'
        expect($scope.dateMfs).toEqual 'date model fields'
        expect($scope.dateCdefs).toEqual 'date custom defs'        

    describe 'updateButton', () ->
      it "calls service's updateButton", () ->        
        deferredUpdate = q.defer()
        spyOn(svc, 'updateButton').andReturn deferredUpdate.promise
        $scope.updateButton(1, "criteria")
        $scope.$apply()
        expect(svc.updateButton).toHaveBeenCalledWith(1, "criteria")
        
    describe 'saveButton', () ->
      it "calls updateButton", () ->
        spyOn($scope, 'updateButton')
        $scope.buttonId = 1
        $scope.stb = {}
        $scope.searchCriterions = "criteria"
        $scope.saveButton()
        expect($scope.updateButton).toHaveBeenCalledWith(1, {criteria: "criteria", stb: {}})

    describe 'resetField', () ->
      it "sets specified field on $scope.stb to be null", () ->
        $scope.stb = {user_custom_definition_id: 1}
        $scope.resetField('user_custom_definition_id')
        expect($scope.user_custom_definition_id).toEqual null


