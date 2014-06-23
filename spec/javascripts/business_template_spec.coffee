describe "BusinessTemplateApp", () ->
  beforeEach module("BusinessTemplateApp")

  describe 'businessTemplateService', () ->
    http = svc = null

    beforeEach inject((businessTemplateService, $httpBackend) ->
      svc = businessTemplateService
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe "editBusinessTemplate", () ->
      it "should make a get request to the correct URL", () ->
        http.expectGET('/business_validation_templates/234/edit_angular').respond("OK")
        svc.editBusinessTemplate("234")
        http.flush()

    describe "updateBusinessTemplate", () ->
      it "should make a put request to the correct URL", () ->
        http.expectPUT('/business_validation_templates/123').respond("OK")
        rule = {id: "123"}
        svc.updateBusinessTemplate(rule)
        http.flush()

  describe "BusinessTemplateController", () ->
    ctrl = scope = svc = win = null

    beforeEach inject ($rootScope, $controller, businessTemplateService) ->
      scope = $rootScope.$new()
      svc = businessTemplateService
      win = { location: {replace : (url) -> console.log "redirected to " + url }}
      ctrl = $controller('BusinessTemplateController', {$scope: scope, $window: win})

    describe "backButton", () ->
      it "should bring you to the correct business template edit page", () ->
        win.location.replace = jasmine.createSpy("replace")
        scope.businessTemplate = {id: "911"}
        scope.backButton()
        expect(win.location.replace).toHaveBeenCalledWith("/business_validation_templates/911/edit")

    describe "editBusinessTemplate", () ->
      it "should make a call to service edit", () ->
        spyOn(svc, 'editBusinessTemplate').andReturn {
          success: (c) -> null
        }
        scope.editBusinessTemplate("5")
        expect(svc.editBusinessTemplate).toHaveBeenCalledWith("5")

      it "should set model_fields and businessTemplate on success", () ->
        myData = {model_fields: [1, 2, 3], business_template: {business_validation_template: "business template"}}
        spyOn(svc, 'editBusinessTemplate').andReturn {
          success: (c) -> c(myData)
        }
        scope.editBusinessTemplate("5")
        expect(scope.model_fields).toEqual [1,2,3]
        expect(scope.businessTemplate).toEqual "business template"

    describe 'updateBusinessTemplate', () ->
      it "should make a call to service update", () ->
        spyOn(svc, 'updateBusinessTemplate').andReturn {
          success: (c) -> null; @
          error: (c) -> null
        }
        scope.businessTemplate = "t"
        scope.updateBusinessTemplate()
        expect(svc.updateBusinessTemplate).toHaveBeenCalledWith("t")