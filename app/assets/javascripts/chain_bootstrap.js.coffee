$("document").ready () ->
  $.each $('#nav-action-bar').find('button'), () ->
    $(@).addClass 'btn'
    $(@).addClass 'navbar-btn'
    $(@).addClass 'btn-default' unless $(@).hasClass('btn-danger')
