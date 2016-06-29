app = angular.module('CustomViewTemplateApp',['ChainComponents'])

app.factory 'customViewTemplateSvc', ($http) ->
  {
    loadTemplate: (id) ->
      $http.get('/custom_view_templates/' + id + '/' + 'edit.json')

    updateTemplate: (id, criteria) ->
      $http.put('/custom_view_templates/' + id, JSON.stringify({'criteria' : criteria}))
  }

app.controller 'customViewTemplateCtrl', ($scope,$location,customViewTemplateSvc,chainSearchOperators) ->

  $scope.getId = (url) ->
    m = url.match(/\d+(?=\/edit)/)
    m[0] if m

  $scope.loadTemplate = (id) ->
    p = customViewTemplateSvc.loadTemplate id
    p.then (data) ->
      basicTemplate = data["data"]["template"]["custom_view_template"]
      $scope.code = basicTemplate["template_identifier"]
      $scope.path = basicTemplate["template_path"]
      $scope.module = basicTemplate["module_type"]
      $scope.search_criterions = data["data"]["criteria"]
      $scope.model_fields = data["data"]["model_fields"]

  $scope.updateTemplate = (id, criteria) ->
    p = customViewTemplateSvc.updateTemplate id, criteria
    p.then () ->
      $location.url('/custom_view_templates')

  $scope.saveTemplate = () ->
    $scope.updateTemplate($scope.templateId, $scope.search_criterions)

  #from advanced_search.js.coffee.erb
  findByMfid = (ary,mfid) ->
    for m in ary
      return m if m.mfid==mfid
    return null

  #adapted from advanced_search.js.coffee.erb
  $scope.addCriterion = (toAddId) ->
    toAdd = {value:''}
    mf = findByMfid $scope.model_fields, toAddId
    toAdd.mfid = mf.mfid
    toAdd.datatype = mf.datatype
    toAdd.label = mf.label
    toAdd.operator = $scope.operators[toAdd.datatype][0].operator
    $scope.search_criterions.push toAdd

  $scope.operators = chainSearchOperators.ops
  $scope.templateId = $scope.getId($location.absUrl())
  registrations = []

  #adapted from advanced_search.js.coffee.erb
  $scope.removeCriterion = (crit) ->
    criterions = $scope.search_criterions
    criterions.splice($.inArray(crit, criterions ),1)

  #adapted from advanced_search.js.coffee.erb
  registrations.push($scope.$watch 'search_criterions', ((newValue, oldValue, watchScope) ->
      return unless watchScope.search_criterions && watchScope.search_criterions.length > 0
      for c in watchScope.search_criterions
        watchScope.removeCriterion(c) if c && c.deleteMe  # Not sure why, but I've seen console errors due to c being null here.
    ), true
  )

  #from advanced_search.js.coffee.erb
  $scope.$on('$destroy', () ->
      deregister() for deregister in registrations
      registrations = null
    )

