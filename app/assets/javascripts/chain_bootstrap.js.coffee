$("document").ready () ->
  $.each $('#nav-action-bar').find('button'), () ->
    $(@).addClass 'btn'
    $(@).addClass 'btn-inverse'
