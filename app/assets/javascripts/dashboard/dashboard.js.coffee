dashboardApp = angular.module('DashboardApp',['ChainComponents', 'LocalStorageModule'])
dashboardApp.directive 'dashboardWidget', ->
  {
    restrict:'E'
    template: "<h3 ng-show='widget.searchResult.name' class='widget_heading py-2' >{{widget.searchResult.name}} - {{widget.searchResult.core_module_name}}</h3><div chain-search-result='widget.searchResult' per-page='perPage' page='page' no-chrome='true' src='/advanced_search/'></div><a ng-show='widget.searchResult.name' class='action_link' href='/advanced_search/{{widgetId}}'>More</a>"
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
dashboardApp.directive 'dashboardNews', [($scope) ->
  restrict: 'E'
  link: (scope) ->
    scope.errors = []
    scope.notices = []
    $.ajax  
      dataType: 'jsonp'  
      url: 'https://www.vandegriftinc.com/news?format=json'  
      success: (data) ->
        $('.loader').remove()
        win = $(window)  
        # Append at least four articles or up to the screen height, but not beyond the number of articles  
        i = 0  
        while i < data.items.length and (i < 4 or $(document).height() - win.height() <= win.scrollTop())  
          newsarticle = data.items[i]
          publishedOn = moment(newsarticle.publishOn).format('LL')  
          articleUrl = 'https://www.vandegriftinc.com/news/' + newsarticle.urlId  
          articleTitle = newsarticle.title  
          bodyText = newsarticle.body  
          bodyText = bodyText.replace(/<[^>]+>/g, '')  
          shortBody = bodyText.substring(0, 250)    
          html = '<p>' + publishedOn + '</p>'  
          html += '<a href="' + articleUrl + '" target="_blank"><h5>' + articleTitle + '</h5></a>'  
          html += '<p>' + shortBody + '... </p><hr/>'
          jQuery('#news-box').append $(html).hide().fadeIn(700) 
          i++  
        return

]
