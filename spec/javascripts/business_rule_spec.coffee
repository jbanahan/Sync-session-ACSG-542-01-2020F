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
        expect(http.flush).not.toThrow()

    describe "updateBusinessRule", () ->
      it "should make a put request to the correct URL", () ->
        http.expectPUT('/business_validation_templates/123/business_validation_rules/234').respond("OK")
        rule = {id: "234", business_validation_template_id: "123"}
        svc.updateBusinessRule(rule)
        expect(http.flush).not.toThrow()

    describe "groupIndex", () ->
      it "makes a get request to the correct URL", () ->
        http.expectGET("/api/v1/groups").respond("OK")
        svc.groupIndex()
        expect(http.flush).not.toThrow()

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
        spyOn(svc, 'editBusinessRule').and.returnValue {
          success: (c) -> null
        }
        scope.editBusinessRule("5")
        expect(svc.editBusinessRule).toHaveBeenCalledWith("5")

      it "should set model_fields, groups, businessRule on success", () ->
        myData = {model_fields: [1, 2, 3], business_validation_rule: "business rule"}
        groupData = {groups: [{id: 1, grp_name: "foo"}, {id: 2, grp_name:"bar"}]}
        spyOn(svc, 'editBusinessRule').and.returnValue {
          success: (c) -> c(myData)
        }
        spyOn(svc, 'groupIndex').and.returnValue {
          success: (c) -> c(groupData)
        }
        scope.editBusinessRule("5")
        expect(scope.model_fields).toEqual [1,2,3]
        expect(scope.groups).toEqual groupData.groups
        expect(scope.businessRule).toEqual "business rule"

    describe 'updateBusinessRule', () ->
      it "should make a call to service update", () ->
        spyOn(svc, 'updateBusinessRule').and.returnValue {
          success: (c) -> null; @
          error: (c) -> null
        }
        scope.businessRule = "br"
        scope.updateBusinessRule()
        expect(svc.updateBusinessRule).toHaveBeenCalledWith("br")
