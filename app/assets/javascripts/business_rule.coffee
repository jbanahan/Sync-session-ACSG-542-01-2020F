root = exports ? this

businessRuleApp = angular.module('BusinessRuleApp', ['ChainComponents'])

businessRuleApp.factory 'businessRuleService', ['$http', ($http) ->
  return {
    editBusinessRule: (id) ->
      return $http.get "/business_validation_rules/" + id + "/edit_angular"

    updateBusinessRule: (businessRule) ->
      return $http.put "/business_validation_templates/" + businessRule.business_validation_template_id + "/business_validation_rules/" + businessRule.id,
        business_validation_rule: businessRule

    groupIndex: () ->
      return $http.get "/api/v1/groups"
  }
]


businessRuleApp.controller 'BusinessRuleController', ['$scope','businessRuleService','chainSearchOperators','$window',($scope,businessRuleService,chainSearchOperators,$window) ->
  $scope.operators = chainSearchOperators.ops

  $scope.backButton = () ->
    $window.location.replace("/business_validation_templates/" + $scope.businessRule.business_validation_template_id + "/edit")
  
  $scope.editBusinessRule = (id) ->
    businessRuleService.editBusinessRule(id).success((data) ->
        $scope.model_fields = data.model_fields
        $scope.businessRule = data.business_validation_rule
        businessRuleService.groupIndex().success((data2) ->
          $scope.groups = data2.groups
        )
      )

  $scope.updateBusinessRule = () ->
    businessRuleService.updateBusinessRule($scope.businessRule).success((data) ->
        $("#rule-criteria-submit-failure").hide()
        $("#notice").text(data.notice)
        $("#rule-criteria-submit-success").show()
      ).error((data) ->
        $("#rule-criteria-submit-success").hide()
        $("#error").text(data.error)
        $("#rule-criteria-submit-failure").show()
      )

  $scope.setId = (id) ->
    $scope.currentId = id
    $scope.editBusinessRule($scope.currentId)

]