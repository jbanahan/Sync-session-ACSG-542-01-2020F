describe 'ChainComments', () ->

  beforeEach module('ChainComments')

  describe 'commentSvc', () ->
    http = svc = null

    beforeEach inject((commentSvc,$httpBackend) ->
      svc = commentSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'injectComments', ->
      it 'should add comments to obj', ->
        resp = {comments:[{id:1}]}
        http.expectGET('/api/v1/comments/for_module/Shipment/2.json').respond resp
        obj = {id:2}
        moduleType = 'Shipment'
        svc.injectComments obj, moduleType
        http.flush()
        expect(obj.comments).toEqual resp.comments
    
    describe 'addComment', ->
      it "should post comment and add to commentArray", ->
        comm = {a:'b'}
        resp = {comment:{id:1}}
        ca = []
        http.expectPOST('/api/v1/comments.json',{comment:comm}).respond resp
        svc.addComment comm, ca
        http.flush()
        expect(ca).toEqual [resp.comment]

    describe 'deleteComment', ->
      it "should delete comment", ->
        comm = {id:3}
        ca = [{id:2},{id:7},{id:3},{id:5}]
        resp = {a:'b'} #doesn't matter what the response is
        http.expectDELETE('/api/v1/comments/3.json').respond resp
        svc.deleteComment comm, ca
        http.flush()
        expect(ca).toEqual [{id:2},{id:7},{id:5}]
