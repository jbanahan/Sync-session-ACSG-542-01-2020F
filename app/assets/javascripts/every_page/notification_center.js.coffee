root = exports ? this
root.ChainNotificationCenter = {
  getMessageCount : (url) ->
    $.getJSON url, (data) ->
      if data > 0
        $('.message_envelope').each () ->
          $(this).html(''+data).addClass('messages')
      else
        $('.message_envelope').each () ->
          $(this).html('').removeClass('messages')


  # If pollingSeconds is <=0, no ongoing polling is done.
  initialize : (user_id, pollingSeconds) ->
    @url = '/messages/message_count?user_id='+user_id

    $(document).ready () =>
      @initNotificationCenter()
      @getMessageCount(@url)
      if pollingSeconds > 0
        @startPolling(pollingSeconds)

  initNotificationCenter : () ->
    # This event doesn't work on IE included with Windows < 10
    document.addEventListener 'visibilitychange', ->
      if document.visibilityState == 'visible'
        ChainNotificationCenter.getMessageCount(ChainNotificationCenter.pollingUrl())

    $('[data-toggle="notification-center"]').click ->
      ChainNotificationCenter.toggleNotificationCenter()

    $('[notification-center-toggle-target]').on 'click', () ->
      ChainNotificationCenter.showNotificationCenterPane($(this).attr('notification-center-toggle-target'))

    $('#notification-center').on 'click', '.delete-message-btn', (evt) ->
      msgId = $(this).attr('message-id')
      evt.preventDefault()
      if(window.confirm('Are you sure you want to delete this message?'))
        $.ajax {
          url:'/messages/'+msgId
          type: "post"
          data: {"_method":"delete"}
          success: () ->
            $('#message-panel-'+msgId).fadeOut()
        }

    $('#notification-center').on 'click', '.show-time-btn', (evt) ->
      t = $(this)
      if(t.html()==t.attr('title'))
        t.html("<span class='fa fa-clock-o'></span>")
      else
        t.html(t.attr('title'))

    $('#notification-center').click (event) ->
      if (event.target == this)
        ChainNotificationCenter.hideNotificationCenter()

    $('#notification-center').on 'show.bs.collapse', '.collapse', (event) ->
      t = event.target
      id = $(t).attr('message-id')
      panel = $('#message-panel-'+id)
      panel.find('.message-read-icon').removeClass('fa-chevron-right').addClass('fa-chevron-down')
      if panel.hasClass('unread')
        panel.addClass('read').removeClass('unread')
        $.get '/messages/'+id+'/read', ->
          ChainNotificationCenter.getMessageCount(ChainNotificationCenter.pollingUrl())

    $('#notification-center').on 'hide.bs.collapse', '.collapse', (event) ->
      t = event.target
      id = $(t).attr('message-id')
      $('#message-panel-'+id+' .message-read-icon').removeClass('fa-chevron-down').addClass('fa-chevron-right')

    $('#notification-center').on 'click', '.notification-mark-all-read', (event) ->
      $.ajax {
        url:'/messages/read_all'
        success: () ->
          $('#notification-center').find('.unread').each () ->
            $(this).removeClass('unread').addClass('read')
          ChainNotificationCenter.getMessageCount(ChainNotificationCenter.pollingUrl())
      }

    $('#notification-center').on 'chain:notification-load', '[notification-center-pane="messages"]', () ->
      $('[notification-center-pane="messages"] .message-body a').addClass('btn').addClass('btn-sm').addClass('btn-primary')


  pollingUrl : ->
    @url

  startPolling : (pollingSeconds) ->
    # If there's an interval registration, we're already polling
    unless @intervalRegistration? || pollingSeconds <= 0
      @intervalRegistration = setInterval( () =>
        unless document.hidden or document.msHidden or document.webkitHidden
          @getMessageCount @url
      , pollingSeconds * 1000)

  stopPolling : () ->
    if @intervalRegistration?
      reg = @intervalRegistration
      @intervalRegistration = null
      clearInterval(reg)

  toggleNotificationCenter: () ->
    if $("#notification-center").is(':visible')
      ChainNotificationCenter.hideNotificationCenter()
    else
      ChainNotificationCenter.showNotificationCenter()

  showNotificationCenter : () ->
    $("#notification-center").modal('show')
    ChainNotificationCenter.showNotificationCenterPane('messages')

  showNotificationCenterPane: (target) ->
    $("[notification-center-pane]").hide()
    $("[notification-center-toggle-target]").removeClass('btn-primary')
    $("[notification-center-toggle-target='"+target+"']").addClass('btn-primary')
    pane = $("[notification-center-pane='"+target+"']")
    pane.html('<div class="loader"></div>')
    pane.show()
    $.ajax {
      url: pane.attr('content-url')
      data: {nolayout:'true'}
      success: (data) ->
        extraTrigger = pane.attr('data-load-trigger')
        pane.html(data)
        pane.trigger('chain:notification-load')
        pane.trigger(extraTrigger) if extraTrigger

      error: () ->
        pane.html "<div class='alert alert-danger'><i class='fa fa-exclamation-triangle' aria-hidden='true'></i>We're sorry, an error occurred while trying to load this information.</div>"
    }

  hideNotificationCenter : () ->
    $("#notification-center").modal('hide')

}
