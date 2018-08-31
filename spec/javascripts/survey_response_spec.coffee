describe "SurveyResponseApp", () ->
  beforeEach module('SurveyResponseApp')

  describe 'srService', () ->
    http = svc = sce = null
    beforeEach inject((srService,$httpBackend,$sce) ->
      svc = srService
      http = $httpBackend
      sce = $sce
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

      it "should mark questions html_content as safe", () ->
        resp = {survey_response:{id:7,answers:[{question:{html_content:'abc'}}]}}
        spyOn(sce,'trustAsHtml')
        http.expectGET('/survey_responses/7.json').respond(resp)
        svc.load(7)
        http.flush()
        expect(sce.trustAsHtml).toHaveBeenCalledWith('abc')


    describe 'invite', () ->
      it "should make send invite call", () ->
        resp = {id:7}
        http.expectGET('/survey_responses/7/invite.json').respond({ok:'ok'})
        svc.invite resp
        expect(resp.success_message).toEqual 'Sending invite.'
        http.flush()
        expect(resp.success_message).toEqual 'Invite sent successfully.'

    describe 'remind', () ->
      it "should make send reminder emails call", () ->
        fields = {email_to: "john.smith@abc.com", email_subject: "Survey you need to take", email_body: "Don't forget the survey!"}
        http.expectPOST('/survey_responses/7/remind', fields).respond({ok:'ok'})
        svc.remind {id: 7}, fields
        expect(http.flush).not.toThrow()
        
    describe 'addAnswerComment', () ->
      
      it "should add the comment to the answer_comments for the appropriate answer", () ->
        resp = {answer_comment:{user:{full_name:'Joe Jackson'},created_at:'2013-05-16 13:19',private:true,content:'mycontent'}}
        http.expectPOST('/answers/1/answer_comments.json',{comment:{content:'mycontent',private:true}}).respond(resp)
        svc.resp.answers = []
        svc.resp.answers.push {id:1,answer_comments:[]}
        answer = svc.resp.answers[0]
        svc.addAnswerComment(answer,'mycontent',true)
        http.flush()
        expect(answer.answer_comments.length).toEqual(1)
        expect(answer.answer_comments[0].user.full_name).toEqual('Joe Jackson')

      it "should work if answer_comments not defined", () ->
        resp = {answer_comment:{user:{full_name:'Joe Jackson'},created_at:'2013-05-16 13:19',private:true,content:'mycontent'}}
        http.expectPOST('/answers/1/answer_comments.json',{comment:{content:'mycontent',private:true}}).respond(resp)
        svc.resp.answers = []
        svc.resp.answers.push {id:1}
        answer = svc.resp.answers[0]
        svc.addAnswerComment(answer,'mycontent',true)
        http.flush()
        expect(answer.answer_comments.length).toEqual(1)
        expect(answer.answer_comments[0].user.full_name).toEqual('Joe Jackson')

      it "should show set error state if failed", () ->
        resp = {error:'some message'}
        http.expectPOST('/answers/1/answer_comments.json',{comment:{content:'mycontent',private:true}}).respond(400,resp)
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
        http.expectPUT('/answers/2.json',{answer:{id:2,choice:'x',rating:'y'}}).respond(resp)
        d = {id:2,choice:'x',rating:'y'}
        svc.saveAnswer(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe(undefined)
    
      it "should fire success callback", () ->
        cbVal = false
        cb = (response) ->
          cbVal = true
        resp = {ok:'ok'}
        http.expectPUT('/answers/2.json',{answer:{id:2,choice:'x',rating:'y'}}).respond(resp)
        d = {id:2,choice:'x',rating:'y'}
        svc.saveAnswer(d,cb)
        http.flush()
        expect(cbVal).toBe true

      it "should show error if save fails", () ->
        resp = {ok:'ok'}
        http.expectPUT('/answers/2.json',{answer:{id:2,choice:'x',rating:'y'}}).respond(500,resp)
        d = {id:2,choice:'x',rating:'y'}
        svc.saveAnswer(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe("There was an error saving your data. Please reload the page.")

    describe "saveContactInfo", () ->
      it "should save", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1.json',{survey_response:{id:1,address:'addr',email:'sample@sample.com',phone:'5555555555',fax:'5554443333',name:'myname'}}).respond(resp)
        d = {id:1,address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveContactInfo(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        
      it "should show error if server call fails", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1.json',{survey_response:{id:1,address:'addr',email:'sample@sample.com',phone:'5555555555',fax:'5554443333',name:'myname'}}).respond(500,resp)
        d = {id:1,rating:'pass',address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveContactInfo(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe("There was an error saving your data. Please reload the page.")

    describe "submit", () ->
      it "should save", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1.json',{do_submit:true}).respond(resp)
        d = {id:1,address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname',can_submit:true}
        svc.submit(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.success_message).toEqual 'Your survey has been submitted successfully.'
        expect(d.can_submit).toBe(false)
        expect(d.status).toBe('Needs Rating')

    describe "saveRating", () ->
      it "should save", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1.json',{survey_response:{id:1,rating:'pass'}}).respond(resp)
        d = {id:1,rating:'pass',address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveRating(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe(undefined)

      it "shoud show error on failure", () ->
        resp = {ok:'ok'}
        http.expectPUT('/survey_responses/1.json',{survey_response:{id:1,rating:'pass'}}).respond(500,resp)
        d = {id:1,rating:'pass',address:'addr',phone:'5555555555',fax:'5554443333',email:'sample@sample.com',name:'myname'}
        svc.saveRating(d)
        expect(d.saving).toBe(true)
        http.flush()
        expect(d.saving).toBe(false)
        expect(d.error_message).toBe("There was an error saving your data. Please reload the page.")

#
# FILTER TESTS
#
  describe "unsavedCommentsFilter", () ->
    filter = null

    beforeEach inject((unsavedCommentsFilter) ->
      filter = unsavedCommentsFilter
    )

    it "should return all with new_comment values", () ->
      answers = [
        {id:1,new_comment:''} #don't find
        {id:2,new_comment:'x'} #find
        {id:3} #don't find
        {id:4,new_comment:'abc'} #find
        ]

      matched = filter(answers)
      expect(matched.length).toEqual 2
      expect(matched[0].id).toEqual 2
      expect(matched[1].id).toEqual 4
      
#
# CONTROLLER TESTS
#
  describe "srController", () ->
    ctrl = svc = $scope = null

    beforeEach inject(($rootScope,$controller,srService) ->
      $scope = $rootScope.$new()
      svc = srService
      ctrl = $controller('srController',{$scope:$scope,srService:svc})
    )

    describe "submit", () ->
      frm = null
      beforeEach () ->
        spyOn(svc,'submit')

      it "should delegate to service if form is valid", () ->
        $scope.resp.survey = {require_contact: true}
        $scope.contact_form = { $valid: true }
        $scope.submit()
        expect(svc.submit).toHaveBeenCalledWith(svc.resp)

      it "should delegate to service if form is not required", () ->
        $scope.resp.survey = {require_contact: false}
        $scope.contact_form = { $valid: false }
        $scope.submit()
        expect(svc.submit).toHaveBeenCalledWith(svc.resp)

      it "should not call service if form is required but not valid", () ->
        $scope.resp.survey = {require_contact: true}
        $scope.contact_form = { $valid: false }
        $scope.submit()
        expect(svc.submit.calls).toBeUndefined
        expect(svc.resp.error_message).toEqual 'You must complete all contact fields before submitting.'

      it "should not call service if all questions aren't answered", () ->
        $scope.resp.survey = {require_contact: true}
        $scope.resp.answers = []
        $scope.contact_form = { $valid: true }
        $scope.resp.answers.push {id:1,answer_comments:[], question: {warning: true}}
        $scope.submit()

        expect(svc.submit.calls).toBeUndefined
        expect(svc.resp.error_message).toEqual "You must answer all required questions. Use the 'Not Answered' filter to identify any questions that still need answers."

        
    it "should delegate saveAnswer", () ->
      spyOn(svc,'saveAnswer').and.callFake (a,c) ->
        c({my:'response'}) if c #execute callback
      
      ans = {id:1,choice:'x'}
      $scope.resp.answers = []
      $scope.resp.answers.push ans
      $scope.saveAnswer(ans)
      expect(svc.saveAnswer).toHaveBeenCalledWith(ans)

    it "should delegate add comment", () ->
      spyOn(svc,'addAnswerComment').and.callFake (a,c,p,e) ->
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
          question: {warning:true, choice_list: ['A', 'B']}
          answer_comments: [{content:'x',user:{id:1}}]
        }
        sr = {survey_takers: [1]}
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
        d.question.choice_list = []
        expect($scope.showWarning(d)).toBe(false)

      it "should not show warning if question warning is true and there's a choice", () ->
        d.answer_comments = []
        expect($scope.showWarning(d)).toBe(false)

      it "should show warning if question warning is true and there's no choice and the comment is not from the assigned user", () ->
        d.choice = null
        d.answer_comments[0].user.id = 2
        expect($scope.showWarning(d)).toBe(true)
      
    describe "hasUnsavedComments", () ->
      it "should return true if response has unsaved comments", () ->
        $scope.resp = {answers:[{id:1},{id:2,new_comment:'x'}]}
        expect($scope.hasUnsavedComments()).toBe(true)

      it "should return false if response doesn't have unsaved comments", () ->
        $scope.resp = {answers:[{id:1},{id:2,new_comment:' '}]}
        expect($scope.hasUnsavedComments()).toBe(false)

    describe "arrangeAnswers", () ->
      
      beforeEach () ->
        $scope.resp.answers = [
          {id:1, rating: 'x', sort_number: 1, updated_at: "2015-01-13", question: {}}
          {id:2, rating: 'y', sort_number: 4, updated_at: "2015-01-14", question: {}}
          {id:3, rating: 'x', sort_number: 2, updated_at: "2015-01-15", question: {}}
          {id:4, rating: 'x', sort_number: 3, updated_at: "2015-01-16", question: {}}
          ]
        $scope.resp.survey_takers = [1]

      it "filters 'All' and sorts 'By Number' by default", () ->
        results = $scope.arrangeAnswers()
        x = []
        x.push r.id for r in results
        expect(x).toEqual([1,3,4,2])

      it "filters and sorts by specified params", () ->
        $scope.srService.settings.filterMode = "Rating: x"
        $scope.srService.settings.sortMode = "By Time Updated"
        results = $scope.arrangeAnswers()
        x = []
        x.push r.id for r in results
        expect(x).toEqual([4, 3, 1])


    describe "sortAnswers", () ->
      answers = null

      beforeEach () ->
        answers = [
          {id:1, sort_number: 1, updated_at: "2015-01-14", question: {}}
          {id:2, sort_number: 3, updated_at: "2015-01-15", question: {}}
          {id:3, sort_number: 2, updated_at: "2015-01-16", question: {}}
        ]

      it "should order by sort number", () ->
        results = $scope.sortAnswers(answers, "By Number")
        x = []
        x.push r.id for r in results
        expect(x).toEqual([1, 3, 2])

      it "should order by most recently updated", () ->
        results = $scope.sortAnswers(answers, "By Time Updated")
        x = []
        x.push r.id for r in results
        expect(x).toEqual([3,2,1])


    describe "filterAnswers", () ->
      answers = null
      
      beforeEach () ->
        answers = [
          {id:1,rating:'x', question: {warning: true}}
          {id:2, question: {}}
          {id:3,rating:null, question: {}}
          {id:4,rating:'x',choice:'y', question: {}}
          {id:5,rating:'x',answer_comments:[{content: "Content", user: {id:1}}], question: {}}
          {id:6,rating:'x',attachments:['y','z'], question: {}}
          {id:7,rating:'y',choice:'y', question: {require_attachment: true}}
          {id:8,rating:'y',choice:'x', question: {require_comment: true}}
          ]
        $scope.resp.survey_takers = [1]

      it "should show all when filter mode is 'All'", () ->
        expect($scope.filterAnswers(answers, "All")).toEqual(answers)

      it "should filter by rating if filter mode starts with 'Rating: '", () ->
        results = $scope.filterAnswers(answers, "Rating: x")
        x = []
        x.push r.id for r in results
        expect(x).toEqual([1,4,5,6])

      it "should show all without rating when filter mode is 'Not Rated'", () ->
        results = $scope.filterAnswers(answers, "Not Rated")
        x = []
        x.push r.id for r in results
        expect(x).toEqual([2,3])

      it "should show all without answer when filter mode is 'Not Answered'", () ->
        results = $scope.filterAnswers(answers, "Not Answered")
        x = []
        x.push r.id for r in results
        expect(x).toEqual([1, 7, 8])
      
    describe "warningMessage", () ->
      answer = null

      beforeEach () -> 
        answer = {id: 1, choice: "", question: {require_comment_for_choices: [], require_attachment_for_choices: []}}
        $scope.resp.survey_takers = [1]

      it "does not show message for answer without errors", () ->
        expect($scope.warningMessage(answer)).toEqual("")

      it "shows warning message for answer without a choice", () ->
        answer.question.warning = true
        answer.question.choice_list = ["A", "B"]
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide an answer.")

      it "shows warning message for answer without a choice list without a comment", () ->
        answer.question.warning = true
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide a comment.")

      it "does not show message for answer with user comment", () ->
        answer.question.warning = true
        answer.answer_comments = [{user: {id: 1}, content: "ABC"}]
        expect($scope.warningMessage(answer)).toEqual("")

      it "shows warning message for answers without comments by user", () ->
        answer.question.warning = true
        answer.answer_comments = [{user: {id: 99}, content: "ABC"}]
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide a comment.")

      it "shows warning message for answers without comments required by question", () ->
        answer.question.require_comment = true
        answer.answer_comments = [{user: {id: 99}, content: "ABC"}]
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide a comment.")

      it "shows warning message for answers without attachments required by question", () ->
        answer.question.require_attachment = true
        answer.attachments = []
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide an attachment.")

      it "shows warning message for answer choice without comment required by question", () ->
        answer.question.require_comment_for_choices.push "A"
        answer.choice = "A"
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide a comment.")

      it "shows warning message for answer choice without attachment required by question", () ->
        answer.question.require_attachment_for_choices.push "A"
        answer.choice = "A"
        expect($scope.warningMessage(answer)).toEqual("This is a required question. You must provide an attachment.")

    describe "setReminderDefaults", () ->

      it "sets $scope.reminderDefaults", () ->
        $scope.setReminderDefaults {user: {email: "john.smith@abc.com"}, survey: {name: "Survey Title"}}
        expect($scope.reminderDefaults).toEqual {email_to: "john.smith@abc.com", \
                                                 email_subject: "Reminder: Survey Title", \
                                                 email_body: "Please follow the link below to complete your survey." }

      it "leaves defaults unchanged if they've already been set", () ->
        originalAssignment = $scope.reminderDefaults = {email_to: "john.smith@abc.com", \
                                                        email_subject: "Reminder: Survey Title", \
                                                        email_body: "Please follow the link below to complete your survey." }

        $scope.setReminderDefaults {user: {email: "sue.anderson@cbs.com"}, survey: {name: "New Survey"}}
        expect($scope.reminderDefaults).toEqual originalAssignment


    describe "setMessageFields", () ->

      it "initializes $scope.messageFields if arg isn't null", () ->
        arg = {email_to: "john.smith@abc.com", email_subject: "Survey you need to take", email_body: "Don't forget the survey!"}
        $scope.setMessageFields arg
        expect($scope.messageFields).toEqual arg

    describe "getEmails", () ->

      it "returns an email if response includes a user", () ->
        resp = {user: {email: "john.smith@abc.com"}}
        expect($scope.getEmails resp).toEqual "john.smith@abc.com"
      
      it "returns a space-separated list of emails if response includes a group", () ->
        resp = {group: {users: [{email: "phil.black@nbc.com"}, {email: "sue.anderson@cbs.com"}]}}
        expect($scope.getEmails resp).toEqual "phil.black@nbc.com sue.anderson@cbs.com"

      it "returns a space-separated list containing user followed by group members if both exist", () ->
        resp = {user: {email: "john.smith@abc.com"}, group: {users: [{email: "phil.black@nbc.com"}, {email: "sue.anderson@cbs.com"}]}}
        expect($scope.getEmails resp).toEqual "john.smith@abc.com phil.black@nbc.com sue.anderson@cbs.com"

    describe "sendEmails", () ->
      beforeEach () ->
        spyOn $scope, 'setErrorPanel'
        spyOn $scope, 'setSuccessPanel'
      
      it "displays confirmation if response is ok", () ->
        spyOn(svc, 'remind').and.returnValue($.Deferred().resolve {ok: "ok"})
        $scope.sendEmails "response", "fields"
        expect(svc.remind).toHaveBeenCalledWith("response","fields")
        expect($scope.setSuccessPanel).toHaveBeenCalledWith("Emails sent")
        
      it "displays an error if response includes one", () ->
        spyOn(svc, 'remind').and.returnValue($.Deferred().reject())
        $scope.sendEmails "response", "fields"
        expect(svc.remind).toHaveBeenCalledWith("response","fields")
        expect($scope.setErrorPanel).toHaveBeenCalledWith("Server temporarily unavailable. Please try again later.")
      
      it "displays an error if response fails", () ->
        spyOn(svc, 'remind').and.returnValue($.Deferred().resolve {error: "ERROR!"})
        $scope.sendEmails "response", "fields"
        expect(svc.remind).toHaveBeenCalledWith("response","fields")
        expect($scope.setErrorPanel).toHaveBeenCalledWith("ERROR!")
