#=require advanced_search

beforeEach module 'AdvancedSearchApp'

describe 'AdvancedSearchCtrl', ->
  scope = {}
  controller = {}
  httpB = {}
  beforeEach inject (_$httpBackend_,$rootScope,$controller) ->
    $httpBackend = _$httpBackend_
    httpB = _$httpBackend_
    scope = $rootScope
    controller = $controller('AdvancedSearchCtrl', { $scope: scope})
  
  describe "editSchedule", ->
    it "should set scheduleToEdit", ->
      x = "ABC"
      scope.editSchedule(x)
      expect(scope.scheduleToEdit).toEqual(x)
