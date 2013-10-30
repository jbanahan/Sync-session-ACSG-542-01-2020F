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

    it "should delegate add comment", () ->
      capSvc.cap = {id:10}
      $scope.survey_response_id = 50
      spyOn(capSvc, 'addComment').andCallFake (a,b,c,d) ->
        d('x')
      $scope.comment = 'abc'
      $scope.addComment()
      expect(capSvc.addComment).toHaveBeenCalledWith('abc',capSvc.cap,50,jasmine.any(Function))
      expect($scope.comment).toEqual('')

    it "should delegate save", () ->
      spyOn(capSvc, 'saveIssue')
      d = {id:30}
      $scope.saveIssue(d)
      expect(capSvc.saveIssue).toHaveBeenCalledWith(d)


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
              
    describe 'saveIssue', () ->
      it "should save", () ->
        d = {id:10}
        http.expectPUT('/corrective_issues/10',{corrective_issue:d}).respond(d)
        svc.saveIssue d
        expect(d.saving).toEqual(true)
        http.flush()
        expect(d.saving).toEqual(false)

    describe 'addComment', () ->
      it "should do put", () ->
        http.expectPOST('/survey_responses/7/corrective_action_plans/1/add_comment',{comment:'xyz'}).respond({comment:{id:99}})
        svc.addComment('xyz',d.corrective_action_plan,7)
        expect(svc.settings.newCommentSaving).toBe(true)
        http.flush()
        expect(svc.settings.newCommentSaving).toBe(false)
        expect(d.corrective_action_plan.comments[0].id).toEqual(99)

      it "should not do anything for blank comment", () ->
        svc.addComment(' \n',d.corrective_action_plan,7)
        #no assertions needed since the httpBackend will blow up if the post is made

      it "should handle error", () ->
        http.expectPOST('/survey_responses/7/corrective_action_plans/1/add_comment',{comment:'xyz'}).respond(401,{error:'x'})
        svc.addComment('xyz',d.corrective_action_plan,7)
        http.flush()
        expect(svc.settings.viewMode).toEqual 'error'

      it "should call success callback", () ->
        commentData = null
        x = (cdata) ->
          commentData = cdata
        http.expectPOST('/survey_responses/7/corrective_action_plans/1/add_comment',{comment:'xyz'}).respond({comment:{id:99}})
        svc.addComment('xyz',d.corrective_action_plan,7,x)
        http.flush()
        expect(commentData).toEqual {comment:{id:99}}


    describe 'addIssue', () ->
      it "should make post", () ->
        svc.cap = d.corrective_action_plan
        http.expectPOST('/corrective_issues',{corrective_action_plan_id:1}).respond({corrective_issue:{id:10}})
        svc.addIssue()
        http.flush()
        expect(svc.cap.corrective_issues[0].id).toEqual 10

    it "should default viewMode to 'loading'", () ->
      expect(svc.settings.viewMode).toEqual('loading')

    it "should set corrective action plan from server data", () ->
      spyOn(svc,'setSettings')
      spyOn(svc,'addIssue')
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
      spyOn(svc,'addIssue')
      svc.setCorrectiveActionPlan d
      expect(svc.addIssue).toHaveBeenCalled()

    it "should load data from the server", () ->
      spyOn(svc,'addIssue')
      http.expectGET(expectUrl).respond(d)
      svc.load(1,2)
      http.flush()
      expect(svc.settings.canEdit).toBe true
      expect(svc.settings.viewMode).toEqual 'edit'
      expect(svc.cap.id).toEqual 1

    describe "remove", () ->
      it "should remove issue", () ->
        http.expectDELETE('/corrective_issues/2').respond({ok:'ok'})
        other_1 = {id:1,x:'y'}
        issue = {id:2,a:'b'}
        other_2 = {id:3,y:'z'}
        d.corrective_action_plan.corrective_issues.push other_1
        d.corrective_action_plan.corrective_issues.push issue
        d.corrective_action_plan.corrective_issues.push other_2
        svc.setCorrectiveActionPlan d
        expect(svc.cap.corrective_issues.length).toEqual(3)
        svc.removeIssue(issue)
        http.flush()
        expect(svc.cap.corrective_issues.length).toEqual(2)
        expect(svc.cap.corrective_issues[0]).toEqual other_1
        expect(svc.cap.corrective_issues[1]).toEqual other_2
