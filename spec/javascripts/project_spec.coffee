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

    describe "editProjectUpdate", () ->
      it "should save and replace in array", () ->
        project = {id:2,project_updates:[{id:3},{id:1},{id:2}]}
        pu = {id:1,project_id:2,body:'x'}
        resp = {project_update:{id:1,project_id:2,body:'y'}}
        http.expectPUT('/projects/2/project_updates/1.json',{project_update:pu}).respond resp
        svc.editProjectUpdate project, pu
        expect(pu.saving).toBe(true)
        http.flush()
        expect(project.project_updates[0]).toEqual({id:3}) # don't replace
        expect(project.project_updates[1]).toEqual(resp.project_update) # replace because IDs match
        expect(project.project_updates[1].saving).toBeFalsy()

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

    describe "removeProjectSet", () ->
      it "should remove project set", () ->
        resp = {project:{id:99}}
        proj = {id:1}
        ps = {id:2,name:'x'}
        http.expectDELETE('/projects/1/remove_project_set/x').respond resp
        svc.removeProjectSet proj, ps
        http.flush()
        expect(svc.project.saving).toBeUndefined()
        expect(svc.project.id).toEqual 99

    describe "addProjectSet", () ->
      it "should add project set", () ->
        resp = {project:{id:99}}
        proj = (id:1)
        pName = 'xyz'
        http.expectPOST('/projects/1/add_project_set/xyz').respond resp
        svc.addProjectSet proj, pName
        http.flush()
        expect(svc.project.saving).toBeUndefined()
        expect(svc.project.id).toEqual 99

  describe 'ProjectCtrl', () ->
    ctrl = svc = $scope = null

    beforeEach inject(($rootScope,$controller,projectSvc) ->
      $scope = $rootScope.$new()
      svc = projectSvc
      mockUserListCache = {
        getListForCurrentUser : (cb) ->
          cb([{id:1,full_name:'User Name'}])
      }
      ctrl = $controller('ProjectCtrl',{$scope:$scope,srService:svc,userListCache:mockUserListCache})
    )

    it "should delegate addProjectSet", () ->
      p = {id:1}
      $scope.projectSetToAdd = 'myset'
      svc.project = p
      spyOn svc, 'addProjectSet'
      $scope.addProjectSet()
      expect(svc.addProjectSet).toHaveBeenCalledWith(p,'myset')

    it "should delegate removeProjectSet", () ->
      p = {id:1}
      ps = {id:2,name:'abc'}
      svc.project = p
      spyOn svc, 'removeProjectSet'
      $scope.removeProjectSet(ps)
      expect(svc.removeProjectSet).toHaveBeenCalledWith p, ps
    
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

    it "should delegate editProjectUpdate", () ->
      p = {id:1}
      svc.project = p
      pu = {id:2}
      spyOn svc, 'editProjectUpdate'
      $scope.editProjectUpdate(pu)
      expect(svc.editProjectUpdate).toHaveBeenCalledWith(p,pu)
