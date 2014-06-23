root = exports ? this

businessRuleApp = angular.module('BusinessRuleApp', ['ChainComponents'])

businessRuleApp.factory 'businessRuleService', ['$http', ($http) ->
  return {
    editBusinessRule: (id) ->
      return $http.get "/business_validation_rules/" + id + "/edit_angular"

    updateBusinessRule: (businessRule) ->
      return $http.put "/business_validation_templates/" + businessRule.business_validation_template_id + "/business_validation_rules/" + businessRule.id,
        business_validation_rule: businessRule,
        search_criterions_only: true
  }
]


businessRuleApp.controller 'BusinessRuleController', ['$scope','businessRuleService','chainSearchOperators','$window',($scope,businessRuleService,chainSearchOperators,$window) ->
  $scope.operators = chainSearchOperators.ops

  $scope.backButton = () ->
    $window.location.replace("/business_validation_templates/" + $scope.businessRule.business_validation_template_id + "/edit")
  
  $scope.editBusinessRule = (id) ->
    businessRuleService.editBusinessRule(id).success((data) ->
        $scope.model_fields = data.model_fields
        $scope.businessRule = data.business_rule
      )

  $scope.updateBusinessRule = () ->
    businessRuleService.updateBusinessRule($scope.businessRule).success((data) ->
        $("#rule-criteria-submit-failure").hide()
        $("#rule-criteria-submit-success").show()
      ).error(() ->
        $("#rule-criteria-submit-failure").show()
        $("#rule-criteria-submit-success").hide()
      )

  $scope.setId = (id) ->
    $scope.currentId = id
    $scope.editBusinessRule($scope.currentId)

]