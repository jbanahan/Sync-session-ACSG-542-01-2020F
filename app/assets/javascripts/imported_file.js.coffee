root = exports ? this
importedFileApp = angular.module('ImportedFileApp',[]).config(['$routeProvider', ($routeProvider) ->
  $routeProvider.
    when('/:fileId',{templateUrl:'/templates/imported_file.html',controller:'ImportedFileController'}).
    otherwise({templateUrl:'/templates/imported_file.html',controller:'ImportedFileController'})
])

importedFileApp.controller 'ImportedFileController', ['$scope', ($scope) ->
  $scope.importedFile = {
    id:1
    file_name:'fn.xls'
    uploaded_at:'2013-01-01'
    uploaded_by:'Brian Glick'
    total_rows:10
    total_records:8
    last_processed:'2013-01-01 12:25'
    time_to_process:3
    }

  $scope.searchResult = {
    id:1
    columns: ['a','b','c']
    rows: [
      {
        id:1
        links:[{label:'View',url:'/product/1'}]
        vals:['a1','b1','c1']
        }
      ]
    }
]
