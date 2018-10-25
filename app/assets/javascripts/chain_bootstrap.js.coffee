$("document").ready () ->
  $.each $('#nav-action-bar').find('button'), () ->
    $(@).addClass 'btn'
    $(@).addClass 'navbar-btn'
    $(@).addClass 'btn-secondary' unless $(@).hasClass('btn-danger')
