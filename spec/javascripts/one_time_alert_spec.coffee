describe 'OneTimeAlertApp', () ->
  beforeEach module('OneTimeAlertApp')

  describe 'service', () ->
    svc = http = null
    beforeEach inject(($httpBackend,oneTimeAlertSvc) ->
      svc = oneTimeAlertSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'loadAlert', () ->
      it "loads", () ->
        returnVal = {alert: "alert",criteria: ["criteria"], model_fields: ["model fields"]}
        http.expectGET('/api/v1/one_time_alerts/1/edit.json').respond returnVal
        promise = svc.loadAlert(1)
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual returnVal

    describe 'updateAlert', () ->
      it "executes PUT route", () ->
        returnVal = {'ok':'ok'}
        criteria = ['criteria']
        alert = {}
        http.expectPUT('/api/v1/one_time_alerts/1', JSON.stringify({criteria:criteria, alert: alert})).respond returnVal
        promise = svc.updateAlert(1, {criteria: criteria, alert: alert})
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual returnVal

  describe 'controller', () ->
    ctrl = svc = $scope = q = loc = null

    beforeEach inject(($rootScope,$controller,$location,$q,oneTimeAlertSvc,chainSearchOperators) ->
      loc = $location
      $scope = $rootScope.$new()
      svc = oneTimeAlertSvc
      ctrl = $controller('oneTimeAlertCtrl',{$scope:$scope})
      q = $q
    )

    describe 'get_id', () ->
      it "extracts id number from url", () ->
        url = "http://www.vfitrack.net/one_time_alerts/123/edit"
        expect($scope.getId(url)).toEqual '123'

    describe 'loadAlert', () ->
      it "calls service's loadAlert and assigns return values to scope", () ->
        data = 
            { 
              "data":{
                "alert":{
                  "one_time_alert":{
                    "name": "alert name",
                    "email_addresses": "abc@123.com",
                    "email_subject": "subject",
                    "email_body": "body",
                    "expire_date": "2018-3-15",
                    "blind_copy_me": true,
                    "module_type": "module"},
                  }
                "criteria": "criteria",
                "model_fields": "model_fields"
                "mailing_lists": "mailing_lists"
              }
            }

        deferredLoad = q.defer()
        deferredLoad.resolve data
        spyOn(svc, 'loadAlert').and.returnValue deferredLoad.promise
        $scope.loadAlert(1)
        $scope.$apply()

        expect(svc.loadAlert).toHaveBeenCalledWith(1)
        expect($scope.alert.name).toEqual 'alert name'
        expect($scope.alert.email_addresses).toEqual 'abc@123.com'
        expect($scope.alert.email_subject).toEqual 'subject'
        expect($scope.alert.email_body).toEqual 'body'
        expect($scope.alert.expire_date).toEqual '2018-3-15'
        expect($scope.alert.blind_copy_me).toEqual true
        expect($scope.alert.module_type).toEqual 'module'
        expect($scope.searchCriterions).toEqual 'criteria'
        expect($scope.modelFields).toEqual 'model_fields'
        expect($scope.mailingLists).toEqual 'mailing_lists'

    describe 'updateAlert', () ->
      it "calls service's updateAlert", () ->        
        deferredUpdate = q.defer()
        spyOn(svc, 'updateAlert').and.returnValue deferredUpdate.promise
        $scope.updateAlert(1, "criteria")
        $scope.$apply()
        expect(svc.updateAlert).toHaveBeenCalledWith(1, "criteria")
        
    describe 'saveAlert', () ->
      it "calls updateAlert", () ->
        spyOn($scope, 'updateAlert')
        $scope.alertId = 1
        $scope.alert = {}
        $scope.searchCriterions = "criteria"
        $scope.send_test = true
        $scope.saveAlert()
        expect($scope.updateAlert).toHaveBeenCalledWith(1, {criteria: "criteria", alert: {}, send_test: true})

    describe 'deleteAlert', () ->
      it "calls service's deleteAlert", () ->
        deferredDelete = q.defer()
        spyOn(svc, 'deleteAlert').and.returnValue deferredDelete.promise
        $scope.deleteAlert(1, "criteria")
        $scope.$apply()
        expect(svc.deleteAlert).toHaveBeenCalledWith(1)

    describe 'cancelAlert', () ->
      it "pulls fresh copy of alert and deletes it if name is missing", () ->
        data = {"data":{ "alert":{ "one_time_alert":{ "name": "" }}}}

        deferredLoad = q.defer()
        deferredLoad.resolve data
        spyOn(svc, 'loadAlert').and.returnValue deferredLoad.promise
        deferredLoad.resolve data

        deferredDelete = q.defer()
        spyOn(svc, 'deleteAlert').and.returnValue deferredDelete.promise

        $scope.cancelAlert 1
        $scope.$apply()
        expect(svc.loadAlert).toHaveBeenCalledWith(1)
        expect(svc.deleteAlert).toHaveBeenCalledWith(1)


