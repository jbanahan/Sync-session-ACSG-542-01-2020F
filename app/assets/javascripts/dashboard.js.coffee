dashboardApp = angular.module('DashboardApp',['ChainComponents'])
dashboardApp.directive 'dashboardWidget', ->
  {
    restrict:'E'
    template: "<h2 ng-show='widget.searchResult.name' class='widget_heading' >{{widget.searchResult.name}} - {{widget.searchResult.core_module_name}}</h2><div chain-search-result='widget.searchResult' per-page='perPage' page='page' no-chrome='true' src='/advanced_search/'></div><a ng-show='widget.searchResult.name' class='action_link' href='/advanced_search/<%=w.search_setup_id%>'>More</a>"
    scope: {
      widgetId: '@'
    }
    link: (scope, el, attrs) ->
      scope.widget = {searchResult:{}}
      scope.page = 1
      scope.perPage = 10
      scope.errors = []
      scope.notices = []

      scope.loadWidget = (searchSetupId) ->
        scope.widget.searchResult.id = searchSetupId

      scope.loadWidget(scope.widgetId)
  }
