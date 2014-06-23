describe "BusinessRuleApp", () ->
  beforeEach module("BusinessRuleApp")

  describe 'businessRuleService', () ->
    http = svc = null

    beforeEach inject((businessRuleService, $httpBackend) ->
      svc = businessRuleService
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe "editBusinessRule", () ->
      it "should make a get request to the correct URL", () ->
        http.expectGET('/business_validation_rules/234/edit_angular').respond("OK")
        svc.editBusinessRule("234")
        http.flush()

    describe "updateBusinessRule", () ->
      it "should make a put request to the correct URL", () ->
        http.expectPUT('/business_validation_templates/123/business_validation_rules/234').respond("OK")
        rule = {id: "234", business_validation_template_id: "123"}
        svc.updateBusinessRule(rule)
        http.flush()

  describe "BusinessRuleController", () ->
    ctrl = scope = svc = win = null

    beforeEach inject ($rootScope, $controller, businessRuleService) ->
      scope = $rootScope.$new()
      svc = businessRuleService
      win = { location: {replace : (url) -> console.log "redirected to " + url }}
      ctrl = $controller('BusinessRuleController', {$scope: scope, $window: win})

    describe "backButton", () ->
      it "should bring you to the correct business template edit page", () ->
        win.location.replace = jasmine.createSpy("replace")
        scope.businessRule = {business_validation_template_id: "911"}
        scope.backButton()
        expect(win.location.replace).toHaveBeenCalledWith("/business_validation_templates/911/edit")

    describe "editBusinessRule", () ->
      it "should make a call to service edit", () ->
        spyOn(svc, 'editBusinessRule').andReturn {
          success: (c) -> null
        }
        scope.editBusinessRule("5")
        expect(svc.editBusinessRule).toHaveBeenCalledWith("5")

      it "should set model_fields and businessRule on success", () ->
        myData = {model_fields: [1, 2, 3], business_rule: "business rule"}
        spyOn(svc, 'editBusinessRule').andReturn {
          success: (c) -> c(myData)
        }
        scope.editBusinessRule("5")
        expect(scope.model_fields).toEqual [1,2,3]
        expect(scope.businessRule).toEqual "business rule"

    describe 'updateBusinessRule', () ->
      it "should make a call to service update", () ->
        spyOn(svc, 'updateBusinessRule').andReturn {
          success: (c) -> null; @
          error: (c) -> null
        }
        scope.businessRule = "br"
        scope.updateBusinessRule()
        expect(svc.updateBusinessRule).toHaveBeenCalledWith("br")