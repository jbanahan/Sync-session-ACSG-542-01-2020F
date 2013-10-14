describe "SurveyResponseApp", () ->
  beforeEach module('SurveyResponseApp')

  describe 'srService', () ->
    http = svc = null
    beforeEach inject((srService,$httpBackend) ->
      svc = srService
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'load', () ->
      it "should set resp based on server response", () ->
        resp = {survey_response:{id:7}}
        http.expectGET('/survey_responses/7.json').respond(resp)
        svc.load(7)
        http.flush()
        expect(svc.resp.id).toEqual(7)

      it "should set viewModes", () ->
        resp = {survey_response:{id:7}}
        http.expectGET('/survey_responses/7.json').respond(resp)
        svc.load(7)
        expect(svc.settings.viewMode).toEqual('loading')
        http.flush()
        expect(svc.settings.viewMode).toEqual('view')

    describe 'addAnswerComment', () ->
      
      it "should add the comment to the answer_comments for the appropriate answer", () ->
        resp = {answer_comment:{user:{full_name:'Joe Jackson'},created_at:'2013-05-16 13:19',private:true,content:'mycontent'}}
        http.expectPOST('/answers/1/answer_comments',{comment:{content:'mycontent',private:true}}).respond(resp)
        svc.resp.answers = []
        svc.resp.answers.push {id:1,answer_comments:[]}
        answer = svc.resp.answers[0]
        svc.addAnswerComment(answer,'mycontent',true)
        http.flush()
        expect(answer.answer_comments.length).toEqual(1)
        expect(answer.answer_comments[0].user.full_name).toEqual('Joe Jackson')

      it "should work if answer_comments not defined", () ->
        resp = {answer_comment:{user:{full_name:'Joe Jackson'},created_at:'2013-05-16 13:19',private:true,content:'mycontent'}}
        http.expectPOST('/answers/1/answer_comments',{comment:{content:'mycontent',private:true}}).respond(resp)
        svc.resp.answers = []
        svc.resp.answers.push {id:1}
        answer = svc.resp.answers[0]
        svc.addAnswerComment(answer,'mycontent',true)
        http.flush()
        expect(answer.answer_comments.length).toEqual(1)
        expect(answer.answer_comments[0].user.full_name).toEqual('Joe Jackson')

      it "should show set error state if failed", () ->
        resp = {error:'some message'}
        http.expectPOST('/answers/1/answer_comments',{comment:{content:'mycontent',private:true}}).respond(400,resp)
        svc.resp.answers = []
        svc.resp.answers.push {id:1,answer_comments:[]}
        answer = svc.resp.answers[0]
        svc.addAnswerComment(answer,'mycontent',true)
        http.flush()
        expect(answer.answer_comments.length).toEqual(0)
        expect(answer.error_message).toEqual("There was an error saving your comment. Please reload the page.")

    describe "saveAnswer", () ->
      it "should save", () ->
        resp = {ok:'ok'}
        http.expectPUT('/answers/2',{answer:{id:2,choice:'x',rating:'y'}}).respond(resp)
        d = {id:2,choice:'x',rating:'y'}
        svc.saveAnswer(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe(undefined)

      it "should show error if save fails", () ->
        resp = {ok:'ok'}
        http.expectPUT('/answers/2',{answer:{id:2,choice:'x',rating:'y'}}).respond(500,resp)
        d = {id:2,choice:'x',rating:'y'}
        svc.saveAnswer(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe("There was an error saving your data. Please reload the page.")

    describe "saveContactInfo", () ->
      it "should save", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1',{survey_response:{id:1,address:'addr',email:'sample@sample.com',phone:'5555555555',fax:'5554443333',name:'myname'}}).respond(resp)
        d = {id:1,address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveContactInfo(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        
      it "should show error if server call fails", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1',{survey_response:{id:1,address:'addr',email:'sample@sample.com',phone:'5555555555',fax:'5554443333',name:'myname'}}).respond(500,resp)
        d = {id:1,rating:'pass',address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveContactInfo(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe("There was an error saving your data. Please reload the page.")

    describe "saveRating", () ->
      it "should save", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1',{survey_response:{id:1,rating:'pass'}}).respond(resp)
        d = {id:1,rating:'pass',address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveRating(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe(undefined)

      it "shoud show error on failure", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1',{survey_response:{id:1,rating:'pass'}}).respond(500,resp)
        d = {id:1,rating:'pass',address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveRating(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe("There was an error saving your data. Please reload the page.")

    describe "answerFilter", () ->
      answers = null
      
      beforeEach () ->
      answers = [
        {id:1,rating:'x'}
        {id:2}
        {id:3,rating:null}
        ]
      it "should show all when filter mode is 'All'", () ->
        svc.settings.filterMode = 'All'
        results = []
        results.push(svc.answerFilter(a)) for a in answers
        expect(results).toEqual([true,true,true])

      it "should show all without rating when filter mode is 'Not Rated'", () ->
        svc.settings.filterMode = 'Not Rated'
        results = []
        results.push(svc.answerFilter(a)) for a in answers
        expect(results).toEqual([false,true,true])

  describe "srController", () ->
    ctrl = svc = $scope = null

    beforeEach inject(($rootScope,$controller,srService) ->
      $scope = $rootScope.$new()
      svc = srService
      ctrl = $controller('srController',{$scope:$scope,srService:svc})
    )

    it "should delegate add comment", () ->
      spyOn(svc,'addAnswerComment').andCallFake (a,c,p,e) ->
        e(answer) #execute callback

      svc.resp.answers = []
      svc.resp.answers.push {id:1,answer_comments:[]}
      answer = svc.resp.answers[0]
      answer.new_comment_private = true
      answer.new_comment = 'xyz'
      
      $scope.addComment(answer)

      expect(svc.addAnswerComment).toHaveBeenCalledWith(answer,'xyz',true,jasmine.any(Function))
      expect(answer.new_comment_private).toBe(null)
      expect(answer.new_comment).toBe(null)

    describe "showWarning", () ->
      sr = d = null
      beforeEach () ->
        d = {
          choice: 'x'
          question: {warning:true}
          answer_comments: [{content:'x',user:{id:1}}]
        }
        sr = {user:{id:1}}
        $scope.resp = sr

      it "should show warning if question warning is true and no comments or choice", () ->
        d.choice = null
        d.answer_comments = []
        expect($scope.showWarning(d)).toBe(true)

      it "should not show warning if question warning is false", () ->
        d.choice = null
        d.answer_comments = []
        d.question.warning = false
        expect($scope.showWarning(d)).toBe(false)
      
      it "should not show warning if question warning is true and there's a comment", () ->
        d.choice = null
        expect($scope.showWarning(d)).toBe(false)

      it "should not show warning if question warning is true and there's a choice", () ->
        d.answer_comments = []
        expect($scope.showWarning(d)).toBe(false)

      it "should show warning if question warning is true and there's no choice and the comment is not from the assigned user", () ->
        d.choice = null
        d.answer_comments[0].user.id = 2
        expect($scope.showWarning(d)).toBe(true)
      
