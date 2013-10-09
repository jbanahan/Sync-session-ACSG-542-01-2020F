describe "SurveyResponseApp", () ->
  beforeEach module('SurveyResponseApp')

  describe 'srService', () ->
    http = svc = null
    beforeEach inject((srService,$httpBackend) ->
      svc = srService
      http = $httpBackend
    )

    describe 'addComment', () ->
      
      it "should add the comment to the answer_comments for the appropriate answer", () ->
      it "should send the comment to the server"
      it "should show set error state if failed"
      

