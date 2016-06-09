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
        http.expectGET('/custom_view_templates/1/edit.json').respond returnVal
        promise = svc.loadTemplate(1)
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        http.flush()
        expect(resolvedPromise).toEqual returnVal

    describe 'updateTemplate', () ->
      it "executes PUT route", () ->
        returnVal = {'ok':'ok'}
        criteria = ['criteria']
        http.expectPUT('/custom_view_templates/1', JSON.stringify({'criteria':criteria})).respond returnVal
        promise = svc.updateTemplate(1, criteria)
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        http.flush()
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
        spyOn(svc, 'loadTemplate').andReturn deferredLoad.promise
        $scope.loadTemplate(1)
        $scope.$apply()

        expect(svc.loadTemplate).toHaveBeenCalledWith(1)
        expect($scope.code).toEqual 'identifier'
        expect($scope.path).toEqual 'path'
        expect($scope.module).toEqual 'module'
        expect($scope.search_criterions).toEqual 'criteria'
        expect($scope.model_fields).toEqual 'model_fields'

    describe 'updateTemplate', () ->
      it "calls service's updateTemplate and then loads index", () ->        
        deferredUpdate = q.defer()
        deferredUpdate.resolve "foo"
        spyOn(svc, 'updateTemplate').andReturn deferredUpdate.promise
        $scope.updateTemplate(1, "criteria")
        $scope.$apply()

        expect(svc.updateTemplate).toHaveBeenCalledWith(1, "criteria")
        expect(loc.url()).toEqual "/custom_view_templates"

    describe 'saveTemplate', () ->
      it "calls updateTemplate", () ->
        spyOn($scope, 'updateTemplate')
        $scope.templateId = 1
        $scope.search_criterions = "criteria"
        $scope.saveTemplate()
        
        expect($scope.updateTemplate).toHaveBeenCalledWith(1, "criteria")


