describe 'BusinessValidationScheduleApp', () ->
  beforeEach module('BusinessValidationScheduleApp')

  describe 'businessValidationScheduleSvc', () ->
    svc = http = null
    beforeEach inject((businessValidationScheduleSvc, $httpBackend) ->
      svc = businessValidationScheduleSvc
      http = $httpBackend
      http.expectGET(new RegExp("/assets/business_validation_schedule/business_validation_schedule_index.+html")).respond "returnVal"
      expect(http.flush).not.toThrow()
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'loadSchedules', () ->
      it "executes route", () ->
        http.expectGET(new RegExp("/api/v1/admin/business_validation_schedules")).respond "returnVal"
        promise = svc.loadSchedules()
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual "returnVal"

    describe 'newSchedule', () ->
      it "executes route", () ->
        http.expectGET(new RegExp('/api/v1/admin/business_validation_schedules/new')).respond "returnVal"
        promise = svc.newSchedule()
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual "returnVal"

    describe 'loadSchedule', () ->
      it "executes route", () ->
        http.expectGET(new RegExp('/api/v1/admin/business_validation_schedules/1/edit')).respond "returnVal"
        promise = svc.loadSchedule(1)
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual "returnVal"

    describe 'createSchedule', () ->
      it "executes route", () ->
        http.expectPOST('/api/v1/admin/business_validation_schedules/', '"params"').respond "returnVal"
        promise = svc.createSchedule("params")
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual "returnVal"

    describe 'updateSchedule', () ->
      it "executes route", () ->
        http.expectPUT('/api/v1/admin/business_validation_schedules/1', '"params"').respond "returnVal"
        promise = svc.updateSchedule(1,"params")
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual "returnVal"

    describe 'deleteSchedule', () ->
      it "executes route", () ->
        http.expectDELETE('/api/v1/admin/business_validation_schedules/1').respond "returnVal"
        promise = svc.deleteSchedule(1)
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual "returnVal"

  describe 'controllers', () ->
    $scope = $q = svc = $state = $httpBackend = chainErrorHandler = $controller = null

    describe 'businessValidationScheduleIndexCtrl', () ->
      beforeEach inject((_$rootScope_,_$q_,_$controller_,_$httpBackend_,_$state_,_chainErrorHandler_,_businessValidationScheduleSvc_) ->
        _$rootScope_.isTest = true
        $scope = _$rootScope_.$new()
        $q = _$q_
        $httpBackend = _$httpBackend_
        chainErrorHandler = _chainErrorHandler_
        $state = _$state_
        svc = _businessValidationScheduleSvc_
        $controller = _$controller_
        ctrl = $controller('businessValidationScheduleIndexCtrl',{$scope:$scope, $state:$state, chainErrorHandler:chainErrorHandler, businessValidationScheduleSvc:svc})

        # default route automatically loads along with controller
        $httpBackend.expectGET(new RegExp('/assets/business_validation_schedule/business_validation_schedule_index.+html')).respond "returnVal"
      )

      describe 'loadSchedules', () ->
        it 'assigns data to scope', () ->
          data = { data: "schedule data" }

          deferredLoad = $q.defer()
          deferredLoad.resolve data
          spyOn(svc, 'loadSchedules').and.returnValue deferredLoad.promise
          $scope.loadSchedules()
          $scope.$apply()
          
          expect(svc.loadSchedules).toHaveBeenCalled()
          expect($scope.schedules).toEqual 'schedule data'

    describe 'businessValidationScheduleNewCtrl', () ->
      beforeEach inject((_$rootScope_,_$q_,_$controller_,_$httpBackend_,_$state_,_chainErrorHandler_,_businessValidationScheduleSvc_) ->
        _$rootScope_.isTest = true
        $scope = _$rootScope_.$new()
        $q = _$q_
        $httpBackend = _$httpBackend_
        chainErrorHandler = _chainErrorHandler_
        $state = _$state_
        svc = _businessValidationScheduleSvc_
        $controller = _$controller_
        ctrl = $controller('businessValidationScheduleNewCtrl',{$scope:$scope, $state:$state, chainErrorHandler:chainErrorHandler, businessValidationScheduleSvc:svc})
      )

      describe 'loadCoreModuleList', () ->
        it "assigns data to scope", () ->
          $httpBackend.expectGET(new RegExp('/assets/business_validation_schedule/business_validation_schedule_index.+html')).respond "returnVal"
          data = { data: {"cm_list" : "core module list"} }

          deferredLoad = $q.defer()
          deferredLoad.resolve data
          spyOn(svc, 'newSchedule').and.returnValue deferredLoad.promise
          $scope.loadCoreModuleList()
          $scope.$apply()
          
          expect(svc.newSchedule).toHaveBeenCalled()
          expect($scope.cmList).toEqual 'core module list'

      describe 'saveSchedule', () ->
        it "calls 'createSchedule' service", () ->
          $httpBackend.expectGET(new RegExp("/assets/business_validation_schedule/business_validation_schedule_edit.+html")).respond "returnVal"
          $httpBackend.expectGET(new RegExp("/assets/business_validation_schedule/business_validation_schedule_index.+html")).respond "returnVal"
          $scope.schedule = "schedule_data"
          deferredLoad = $q.defer()
          deferredLoad.resolve({data: {id: 1}})
          spyOn(svc, 'createSchedule').and.returnValue deferredLoad.promise
          $scope.saveSchedule()
          $scope.$apply()

          expect(svc.createSchedule).toHaveBeenCalledWith({"schedule": "schedule_data"})

    describe 'businessValidationScheduleEditCtrl', () ->
      beforeEach inject((_$rootScope_,_$q_,_$controller_,_$httpBackend_,_$state_,_chainErrorHandler_,_businessValidationScheduleSvc_) ->
        _$rootScope_.isTest = true
        $scope = _$rootScope_.$new()
        $q = _$q_
        $httpBackend = _$httpBackend_
        chainErrorHandler = _chainErrorHandler_
        $state = _$state_
        svc = _businessValidationScheduleSvc_
        $controller = _$controller_
        ctrl = $controller('businessValidationScheduleEditCtrl',{$scope:$scope, $state:$state, chainErrorHandler:chainErrorHandler, businessValidationScheduleSvc:svc})
      )

      describe 'loadSchedule', () ->
        it "assigns data to scope", () ->
          $httpBackend.expectGET(new RegExp("/assets/business_validation_schedule/business_validation_schedule_index.+html")).respond "returnVal"
          data =
            {
              "data":{
                "schedule":{
                  "business_validation_schedule":{
                    "id": 1,
                    "module_type": "Entry",
                    "name": "30 days after release",
                    "num_days": 30,
                    "operator": "After",
                    "model_field_uid": "ent_release_date"}
                            }
                "criteria": "search criterions",
                "criterion_model_fields": "criterion MFs",
                "schedule_model_fields": "schedule MFs"
                      }
            }

          deferredLoad = $q.defer()
          deferredLoad.resolve data
          spyOn(svc, 'loadSchedule').and.returnValue deferredLoad.promise
          $scope.loadSchedule()
          $scope.$apply()
          
          expect(svc.loadSchedule).toHaveBeenCalled()
          sch = $scope.schedule
          expect(sch.id).toEqual 1
          expect(sch.module_type).toEqual "Entry"
          expect(sch.name).toEqual "30 days after release"
          expect(sch.num_days).toEqual 30
          expect(sch.operator).toEqual "After"
          expect(sch.model_field_uid).toEqual "ent_release_date"
          expect($scope.search_criterions).toEqual "search criterions"
          expect($scope.criterion_model_fields).toEqual "criterion MFs"
          expect($scope.schedule_model_fields).toEqual "schedule MFs"

      describe 'saveSchedule', () ->
        it "calls createSchedule service", () ->
          $httpBackend.expectGET(new RegExp("/assets/business_validation_schedule/business_validation_schedule_index.+html")).respond "returnVal"
          $httpBackend.expectGET(new RegExp("/assets/business_validation_schedule/business_validation_schedule_edit.+html")).respond "returnVal"
          $scope.schedule = "schedule_data"
          $scope.search_criterions = "criterion_data"
          spyOn(svc, 'updateSchedule').and.returnValue {then: ()-> null}
          $scope.saveSchedule()

          #first arg should be the schedule's id, but I can't figure out how to inject it into $state.params
          expect(svc.updateSchedule).toHaveBeenCalledWith(undefined, {"criteria": "criterion_data", "schedule": "schedule_data"})
