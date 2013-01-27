root = exports ? this
root.ChainMailboxes =
  #format the list of mailboxes
  applyIndexLayout : ->
    $("#mailbox_accordion").accordion {header:'.mailbox_title'}

  #get the message list from the server and render it
  loadMessageList : (messageListContainer,mailboxId) ->
    messageListContainer.html("Loading...")
    $.get "/mailboxes/"+mailboxId+".json", (data) ->
      ChainMailboxes.renderMessageList messageListContainer, data

  #show message list on screen
  renderMessageList : (messageListContainer,data) ->
    renderEmail = (e) ->
      h = "<div class='message_entry'><a href='#' data-action='view-email' email-id='"+e.id+"'>"+e.subject+"</a>"
      h += "<div class='message_info'>"+e.from+" | "+Chain.formatJSONDate(e.created_at,true)+"</div>"
      h += "</div>"
      aTo = if e.assigned_to_id then e.assigned_to_id else 0
      $("div.user_entry[user-id='"+aTo+"']").append(h)
    renderUser = (u) ->
      "<div class='user_header'>"+u.full_name+"</div><div class='user_entry' user-id='"+u.id+"'></div>"
    h = "<div class='message_list_inner' style='display:none;'><div class='message_list_title'>"+data.name+"</div><div class='user_accordion'>"
    h += "<div class='user_header'>Not Assigned</div><div class='user_entry' user-id='0'></div>"
    h += renderUser(u) for u in data.users
    h += "</div>"
    messageListContainer.html(h)
    h += renderEmail(e) for e in data.emails
    messageListContainer.find(".user_accordion").accordion {header:'.user_header',heightStyle:'content'}
    messageListContainer.find("div.message_list_inner").show("slide",{direction:"left"},500)

  init : (messageListContainer) ->
    ChainMailboxes.applyIndexLayout()
    $("a[data-action='view-mailbox']").live 'click', (evt) ->
      evt.preventDefault()
      ChainMailboxes.loadMessageList messageListContainer, $(@).attr('mailbox-id')
    $("a[data-action='view-email']").live 'click', (evt) ->
      evt.preventDefault()
      window.location = "/emails/"+$(@).attr('email-id')
