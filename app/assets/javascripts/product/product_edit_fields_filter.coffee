# filters an array of fields and only returns those that the users
# should get in an edit dialog
angular.module('ProductApp').filter('productEditFields', ->
  (input) ->
    return input unless input && input.length > 0
    $.grep(input, (fld) ->
      return null if fld.uid.match(/^\*fhts/)
      return fld
    )
)