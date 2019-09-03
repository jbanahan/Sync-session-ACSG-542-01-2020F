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
    businessRuleService.editBusinessRule(id).then((resp) ->
        $scope.model_fields = resp.data.model_fields
        $scope.businessRule = resp.data.business_validation_rule
        businessRuleService.groupIndex().then((resp2) ->
          $scope.groups = resp2.data.groups
        )
      )

  $scope.updateBusinessRule = () ->
    businessRuleService.updateBusinessRule($scope.businessRule).then((resp) ->
        $("#rule-criteria-submit-failure").hide()
        $("#notice").text(resp.data.notice)
        $("#rule-criteria-submit-success").show()
        window.scrollTo(0,0)
      ,(resp) ->
        $("#rule-criteria-submit-success").hide()
        $("#error").text(resp.data.error)
        $("#rule-criteria-submit-failure").show()
        window.scrollTo(0,0)
      )

  $scope.setId = (id) ->
    $scope.currentId = id
    $scope.editBusinessRule($scope.currentId)

]
