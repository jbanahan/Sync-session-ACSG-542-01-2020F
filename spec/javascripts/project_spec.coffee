describe "ProjectApp", () ->
  beforeEach module('ProjectApp')
  
  describe 'projectSvc', () ->
    http = svc = null

    beforeEach inject((projectSvc,$httpBackend) ->
      svc = projectSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()
    
    describe 'load', () ->
      it "should set project based on server response", () ->
        resp = {project:{id:1}}
        http.expectGET('/projects/1.json').respond resp
        svc.load 1
        expect(svc.loadingMessage).toEqual 'Loading...'
        http.flush()
        expect(svc.loadingMessage).toBeNull()
        expect(svc.project.id).toEqual 1

      it "should set error message if failed", () ->
        resp = {error:'x'}
        http.expectGET('/projects/1.json').respond 401, resp
        svc.load 1
        http.flush()
        expect(svc.project).toBeNull()
        expect(svc.errorMessage).toEqual 'x'
        expect(svc.loadingMessage).toBeNull()

    describe "saveProject", () ->
      it "should save", () ->
        resp = {project:{id:99}}
        proj = {id:1,name:'x'}
        http.expectPUT('/projects/1.json',{project:proj}).respond resp
        svc.saveProject proj
        expect(proj.saving).toBe(true)
        http.flush()
        expect(svc.project.saving).toBeUndefined()
        expect(svc.project.id).toEqual 99

    describe "addProjectUpdate", () ->
      it "should save and add to array", () ->
        proj = {id:1}
        resp = {project_update:{id:99,body:'xyz',created_by_full_name:'cfn'}}
        http.expectPOST('/projects/1/project_updates.json',{project_update:{body:'abc'}}).respond resp
        svc.addProjectUpdate proj, 'abc'
        expect(proj.saving).toBe(true)
        http.flush()
        expect(proj.saving).toBeFalsy()
        expect(proj.project_updates[0]).toEqual resp.project_update

    describe "toggleClose", () ->
      it "should toggle and reload", () ->
        resp = {project:{id:99}}
        proj = {id:1}
        http.expectPUT('/projects/1/toggle_close.json').respond resp
        svc.toggleClose proj
        expect(proj.saving).toBe true
        http.flush()
        expect(svc.project.saving).toBeUndefined()
        expect(svc.project.id).toEqual 99

  describe 'ProjectCtrl', () ->
    ctrl = svc = $scope = null

    beforeEach inject(($rootScope,$controller,projectSvc) ->
      $scope = $rootScope.$new()
      svc = projectSvc
      ctrl = $controller('ProjectCtrl',{$scope:$scope,srService:svc})
    )
    
    it "should delegate saveProject", () ->
      p = {id:1}
      svc.project = p
      spyOn svc, 'saveProject'
      $scope.saveProject()
      expect(svc.saveProject).toHaveBeenCalledWith p

    it "should delegate toggleClose", () ->
      p = {id:1}
      svc.project = p
      spyOn svc, 'toggleClose'
      $scope.toggleClose()
      expect(svc.toggleClose).toHaveBeenCalledWith p
