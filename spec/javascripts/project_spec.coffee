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

    describe "toggleOnHold", () ->
      it "should toggle and reload", () ->
        resp = {project:{id:99}}
        proj = {id:1}
        http.expectPUT('/projects/1/toggle_on_hold.json').respond resp
        svc.toggleOnHold proj
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

    describe 'getDeliverables', () ->
      it "should get deliverables and return promise", () ->
        resp = {x:'y'}
        http.expectGET('/project_deliverables.json?layout=x').respond resp
        promise = svc.getDeliverables('x')
        promise.then (r) ->
          expect(r.data).toEqual resp
        http.flush()

  describe 'chainProjectDeliverableEdit', () ->
    svc = $scope = project = deliverable = compile = el = null
    
    beforeEach inject ($rootScope,$compile,projectSvc,$templateCache) ->
      compile = $compile
      $scope = $rootScope
      svc = projectSvc
      $templateCache.put('/assets/chain_project_deliverable_edit.html','<div><div class="modal"><button id="fakebutton">def</button>abc</div></div>')
      mockCallback = (p) ->
        null
      deliverable = {id:1,project_id:2}
      svc.deliverableToEdit = deliverable
      $scope.savePromiseCallback = mockCallback
      element = angular.element("<chain-project-deliverable-edit save-promise-callback='savePromiseCallback'></div>")
      el = compile(element)($scope)
      @

    it "should delegate saveDeliverable", () ->
      promise = {
        error:(f) ->
          null
        success:(f) ->
          null
      }
      spyOn(svc, 'saveDeliverable').andReturn(promise)
      $scope.$digest()
      el.find('#fakebutton').scope().saveDeliverable()
      expect(svc.saveDeliverable).toHaveBeenCalledWith({id:2},deliverable)

    it "should call savePromiseCallback", () ->
      promise = {
        error:(f) ->
          null
        success:(f) ->
          null
      }
      spyOn(svc, 'saveDeliverable').andReturn(promise)
      spyOn($scope,'savePromiseCallback')
      $scope.$digest()
      el.find('#fakebutton').scope().saveDeliverable()
      expect($scope.savePromiseCallback).toHaveBeenCalledWith(promise)

    it "should set error message if save fails", () ->
      promise = {
        error:(f) ->
          f({error:'xyz'},null,null,null)
        success:(f) ->
          null
      }
      spyOn(svc, 'saveDeliverable').andReturn(promise)
      $scope.$digest()
      el.find('#fakebutton').scope().saveDeliverable()
      expect(el.find('#fakebutton').scope().errors.errorMessage).toEqual('xyz')
      
  describe 'ProjectCtrl', () ->
    ctrl = svc = $scope = win = null

    beforeEach inject ($rootScope,$controller,projectSvc) ->
      $scope = $rootScope.$new()
      svc = projectSvc
      win = { location: { replace: (url) -> console.log "redirected to " + url }}
      mockUserListCache = {
        getListForCurrentUser : (cb) ->
          cb([{id:1,full_name:'User Name'}])
      }
      ctrl = $controller('ProjectCtrl',{$scope: $scope, srService: svc, userListCache: mockUserListCache, $window: win})

    describe "showingLastProject", () ->
      it "should return true if and only if the last project is being shown", () ->
        $scope.orderedIds = [1, 2, 3, 4, 10]
        $scope.projectId = 10
        expect($scope.showingLastProject()).toEqual true

        $scope.projectId = 4
        expect($scope.showingLastProject()).toEqual false

    describe "showingFirstProject", () ->
      it "should return true if and only if the first project is being shown", () ->
        $scope.orderedIds = [10, 20, 32, 5, 15, 70]
        $scope.projectId = 10
        expect($scope.showingFirstProject()).toEqual true

        $scope.projectId = 20
        expect($scope.showingFirstProject()).toEqual false

    describe "previousProject", () ->
      it "should call window.replace with the correct ID", () ->
        win.location.replace = jasmine.createSpy("replace")
        $scope.orderedIds = [10, 9, 8, 7, 6, 5]
        $scope.projectId = 8
        $scope.previousProject()
        expect(win.location.replace).toHaveBeenCalledWith("/projects/9")

    describe "nextProject", () ->
      it "should call window.replace with the correct ID", () ->
        win.location.replace = jasmine.createSpy("replace")
        $scope.orderedIds = [10, 9, 8, 7, 6, 5]
        $scope.projectId = 8
        $scope.nextProject()
        expect(win.location.replace).toHaveBeenCalledWith("/projects/7")

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

    it "should delegate toggleOnHold", () ->
      p = {id:1}
      svc.project = p
      spyOn svc, 'toggleOnHold'
      $scope.toggleOnHold()
      expect(svc.toggleOnHold).toHaveBeenCalledWith p

    it "should delegate editProjectUpdate", () ->
      p = {id:1}
      svc.project = p
      pu = {id:2}
      spyOn svc, 'editProjectUpdate'
      $scope.editProjectUpdate(pu)
      expect(svc.editProjectUpdate).toHaveBeenCalledWith(p,pu)
