describe 'HMApp', () ->
  beforeEach module('HMApp')

  describe 'controller', () ->
    ctrl = $scope = svc = null
    
    beforeEach inject(($rootScope,$controller,hmService) ->
      $scope = $rootScope.$new()
      svc = hmService
      ctrl = $controller('HMPOLineController',{$scope:$scope,hmService:svc})
    )

    it "should initialize with empty PO Line", () ->
      expect($scope.poLine).toEqual({})
