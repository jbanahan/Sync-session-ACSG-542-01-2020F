angular.module('ChainComponents').factory 'stateToggleButtonSvc', ['$http', '$q', ($http,$q) ->
  return {
    getButtons: (pluralModuleType,objectId) ->
      d = $q.defer()
      $http.get('/api/v1/'+pluralModuleType.toLowerCase()+'/'+objectId+'/state_toggle_buttons.json').then (resp) ->
        d.resolve(resp.data)
      d.promise
    toggleButton: (button) ->
      return $http.post('/api/v1/'+button.core_module_path+'/'+button.base_object_id+'/toggle_state_button.json',{button_id:button.id})
  }
]