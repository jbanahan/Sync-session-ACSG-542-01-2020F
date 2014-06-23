root = exports ? this

businessTemplateApp = angular.module('BusinessTemplateApp', ['ChainComponents'])

businessTemplateApp.factory 'businessTemplateService', ['$http', ($http) ->
  return {
    editBusinessTemplate: (id) ->
      return $http.get "/business_validation_templates/" + id + "/edit_angular"

    updateBusinessTemplate: (businessTemplate) ->
      return $http.put "/business_validation_templates/" + businessTemplate.id,
        business_validation_template: businessTemplate
        search_criterions_only: true
  }
]

businessTemplateApp.controller 'BusinessTemplateController', ['$scope','businessTemplateService','chainSearchOperators','$window',($scope, businessTemplateService, chainSearchOperators, $window) ->
  $scope.operators = chainSearchOperators.ops

  $scope.backButton = () ->
    $window.location.replace("/business_validation_templates/" + $scope.businessTemplate.id + "/edit")

  $scope.editBusinessTemplate = (id) ->
    businessTemplateService.editBusinessTemplate(id).success((data) ->
        $scope.model_fields = data.model_fields
        $scope.businessTemplate = data.business_template.business_validation_template
      )

  $scope.updateBusinessTemplate = () ->
    businessTemplateService.updateBusinessTemplate($scope.businessTemplate).success((data) ->
        $("#template-criteria-submit-failure").hide()
        $("#template-criteria-submit-success").show()
      ).error(() ->
        $("#template-criteria-submit-failure").show()
        $("#template-criteria-submit-success").hide()
      )

  $scope.setId = (id) ->
    $scope.currentId = id
    $scope.editBusinessTemplate($scope.currentId)

]