describe 'CorrectiveActionPlanApp', () ->
  beforeEach module('CorrectiveActionPlanApp')
  
  describe 'controller', () ->
    ctrl = $scope = capSvc = null

    beforeEach inject(($rootScope,$controller,correctiveActionPlanService) ->
      $scope = $rootScope.$new()
      capSvc = correctiveActionPlanService
      ctrl = $controller('CorrectiveActionPlanController',{$scope:$scope,correctiveActionPlanService:capSvc})
    )

    it "should delegate add issue", () ->
      spyOn(capSvc,'addIssue')
      $scope.addIssue()
      expect(capSvc.addIssue).toHaveBeenCalled()

    it "should delegate save", () ->
      spyOn(capSvc, 'save').andCallFake(() ->
        null
      )
      $scope.survey_response_id = 1
      $scope.corrective_action_plan_id = 2
      $scope.save()
      expect(capSvc.save).toHaveBeenCalledWith(1,2)

    it "should delegate remove", () ->
      spyOn(capSvc, 'removeIssue').andCallFake(() ->
        null
      )
      issue = {a:'b'}
      $scope.remove(issue)
      expect(capSvc.removeIssue).toHaveBeenCalledWith(issue)

  describe 'service', () ->
    d = svc = http = null
    expectUrl = '/survey_responses/1/corrective_action_plans/2.json'
    beforeEach inject(($httpBackend,correctiveActionPlanService) ->
      d = {
        can_edit: true
        corrective_action_plan:{id:1,corrective_issues:[]}
        can_update_actions:true
        }
      svc = correctiveActionPlanService
      http = $httpBackend
    )
    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()
              
    
    it "should default viewMode to 'loading'", () ->
      expect(svc.settings.viewMode).toEqual('loading')

    it "should set corrective action plan from server data", () ->
      spyOn(svc,'setSettings')
      expect(svc.cap.id).toBeUndefined()
      svc.setCorrectiveActionPlan(d)
      expect(svc.cap.id).toEqual(1)
      expect(svc.setSettings).toHaveBeenCalledWith d

    it "should set settings", () ->
      expect(svc.settings.canEdit).toBe(false)
      expect(svc.settings.canUpdateActions).toBe(false)
      svc.setSettings d
      expect(svc.settings.canEdit).toBe(true)
      expect(svc.settings.canUpdateActions).toBe(true)

    it "should add issue if cap has no issues and user can edit", () ->
      svc.setCorrectiveActionPlan d
      expect(svc.cap.corrective_issues.length).toEqual(1)

    it "should load data from the server", () ->
      http.expectGET(expectUrl).respond(d)
      svc.load(1,2)
      http.flush()
      expect(svc.settings.canEdit).toBe true
      expect(svc.settings.viewMode).toEqual 'edit'
      expect(svc.cap.id).toEqual 1

    describe "remove", () ->
      it "should remove issue", () ->
        other_1 = {x:'y'}
        issue = {a:'b'}
        other_2 = {y:'z'}
        d.corrective_action_plan.corrective_issues.push other_1
        d.corrective_action_plan.corrective_issues.push issue
        d.corrective_action_plan.corrective_issues.push other_2
        svc.setCorrectiveActionPlan d
        expect(svc.cap.corrective_issues.length).toEqual(3)
        svc.removeIssue(issue)
        expect(svc.cap.corrective_issues.length).toEqual(2)
        expect(svc.cap.corrective_issues[0]).toEqual other_1
        expect(svc.cap.corrective_issues[1]).toEqual other_2

    
    describe "save", () ->
      it "should set viewMode to saving", () ->
        http.expectPUT(expectUrl,{comment:'abc',corrective_action_plan:d}).respond(d)
        svc.cap = d
        svc.comment = 'abc'
        svc.save(1,2)
        expect(svc.settings.viewMode).toEqual 'saving'
        http.flush()
        expect(svc.settings.viewMode).toEqual 'edit'

      it "should clear comment", () ->
        http.expectPUT(expectUrl,{comment:'abc',corrective_action_plan:d}).respond(d)
        svc.cap = d
        svc.comment = 'abc'
        svc.save(1,2)
        http.flush()
        expect(svc.comment).toEqual ''

      it "should not clear comment on error", () ->
        http.expectPUT(expectUrl,{comment:'abc',corrective_action_plan:d}).respond(500,{msg:'bad'})
        svc.cap = d
        svc.comment = 'abc'
        svc.save(1,2)
        http.flush()
        expect(svc.settings.viewMode).toEqual 'error'
        expect(svc.comment).toEqual 'abc'

