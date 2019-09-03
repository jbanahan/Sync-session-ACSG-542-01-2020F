describe 'CustomViewTemplateApp', () ->
  beforeEach module('CustomViewTemplateApp')

  describe 'service', () ->
    svc = http = null
    beforeEach inject(($httpBackend,customViewTemplateSvc) ->
      svc = customViewTemplateSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'loadTemplate', () ->
      it "loads", () ->
        returnVal = {template: "template",criteria: ["criteria"], model_fields: ["model fields"]}
        http.expectGET('/api/v1/admin/custom_view_templates/1/edit.json').respond returnVal
        promise = svc.loadTemplate(1)
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual returnVal

    describe 'updateTemplate', () ->
      it "executes PUT route", () ->
        returnVal = {'ok':'ok'}
        criteria = ['criteria']
        cvt = {}
        http.expectPUT('/api/v1/admin/custom_view_templates/1', JSON.stringify({criteria:criteria, cvt: cvt})).respond returnVal
        promise = svc.updateTemplate(1, {criteria: criteria, cvt: cvt})
        resolvedPromise = null
        promise.then (resp) ->
          resolvedPromise = resp.data
        expect(http.flush).not.toThrow()
        expect(resolvedPromise).toEqual returnVal

  describe 'controller', () ->
    ctrl = svc = $scope = q = loc = null

    beforeEach inject(($rootScope,$controller,$location,$q,customViewTemplateSvc,chainSearchOperators) ->
      loc = $location
      $scope = $rootScope.$new()
      svc = customViewTemplateSvc
      ctrl = $controller('customViewTemplateCtrl',{$scope:$scope})
      q = $q
    )

    describe 'get_id', () ->
      it "extracts id number from url", () ->
        url = "http://www.vfitrack.net/custom_view_templates/123/edit"
        expect($scope.getId(url)).toEqual '123'

    describe 'loadTemplate', () ->
      it "calls service's loadTemplate and assigns return values to scope", () ->
        data =
            {
              "data":{
                "template":{
                  "custom_view_template":{
                    "template_identifier": "identifier",
                    "template_path": "path",
                    "module_type": "module"},
                  }
                "criteria": "criteria",
                "model_fields": "model_fields"
              }
            }

        deferredLoad = q.defer()
        deferredLoad.resolve data
        spyOn(svc, 'loadTemplate').and.returnValue deferredLoad.promise
        $scope.loadTemplate(1)
        $scope.$apply()

        expect(svc.loadTemplate).toHaveBeenCalledWith(1)
        expect($scope.cvt.template_identifier).toEqual 'identifier'
        expect($scope.cvt.template_path).toEqual 'path'
        expect($scope.cvt.module_type).toEqual 'module'
        expect($scope.searchCriterions).toEqual 'criteria'
        expect($scope.modelFields).toEqual 'model_fields'

    describe 'updateTemplate', () ->
      it "calls service's updateTemplate", () ->
        deferredUpdate = q.defer()
        spyOn(svc, 'updateTemplate').and.returnValue deferredUpdate.promise
        $scope.updateTemplate(1, "criteria")
        $scope.$apply()
        expect(svc.updateTemplate).toHaveBeenCalledWith(1, "criteria")

    describe 'saveTemplate', () ->
      it "calls updateTemplate", () ->
        spyOn($scope, 'updateTemplate')
        $scope.templateId = 1
        $scope.cvt = {}
        $scope.searchCriterions = "criteria"
        $scope.saveTemplate()

        expect($scope.updateTemplate).toHaveBeenCalledWith(1, {criteria: "criteria", cvt: {}})


