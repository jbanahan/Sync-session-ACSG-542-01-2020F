root = exports ? this
root.ChainMailboxes =
  
  currentMailboxData : ->
    @mailboxData

  messageContainer : ->
    @messageListContainer

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
    @mailboxData = data
    renderEmail = (e) ->
      h = "<div class='message_entry'><input type='checkbox' value='"+e.id+"' class='email_selector' /><a href='#' data-action='view-email' email-id='"+e.id+"'>"+e.subject+"</a>"
      h += "<div class='message_info'>"+e.from+" | "+Chain.formatJSONDate(e.created_at,true)+"</div>"
      h += "</div>"
      aTo = if e.assigned_to_id then e.assigned_to_id else 0
      $("div.user_entry[user-id='"+aTo+"']").append(h)
    renderUser = (u) ->
      "<div class='user_header'>"+u.full_name+"</div><div class='user_entry' user-id='"+u.id+"'></div>"
    h = "<div class='message_list_inner' style='display:none;'><div class='message_list_title'>"+data.name+"</div>"
    h += "<div id='message_controls' style='display:none;'><div class='count_message'><span id='selected_count'></span> Message<span id='selected_plural'></span> Selected</div> <a href='#' data-action='assign-emails'>Assign</a> | <a href='#' data-action='clear-email-selection'>Clear</a></div>"
    h += "<div class='users'>"
    h += "<div class='user_header'>Not Assigned</div><div class='user_entry' user-id='0'></div>"
    h += renderUser(u) for u in data.users
    h += "</div>"
    messageListContainer.html(h)
    h += renderEmail(e) for e in data.emails
    messageListContainer.find(".users").accordion {header:'.user_header',heightStyle:'content',collapsible:true}
    messageListContainer.find("div.message_list_inner").show("slide",{direction:"left"},500)

  #turn the bulk actions controls on or off
  setMessageControls : (container) ->
    c = container.find('input.email_selector:checked').size()
    $("#selected_count").html(c)
    $("#selected_plural").html((if c>1 then "s" else ""))
    if c > 0
      $("#message_controls").slideDown()
    else
      $("#message_controls").slideUp()

  showAssignPrompt :  ->
    return unless @mailboxData
    h = "<div id='assign_email_container' style='display:none;'>Assign To: <select>"
    h += "<option value='0'>Nobody</option>"
    h += "<option value='"+u.id+"'>"+u.full_name+"</option>" for u in @mailboxData.users
    h += "</select></div>"
    $("body").append(h)
    buttons = {
    "Assign": ->
      uId = $('#assign_email_container select').val()
      $("#assign_email_container").remove()
      ChainMailboxes.assignEmails uId
    }
    $("#assign_email_container").dialog {modal:true,title:"Assign Email",buttons:buttons}

  assignEmails : (userId) ->
    $("form.email_assign").remove() #clear any old forms laying around
    h = "<form class='email_assign' data-remote='true' style='display:none;'><input type='hidden' name='user_id' value='"+userId+"'/>"
    h += "<input type='hidden' name='email["+i+"][id]' value='"+$(e).val()+"' />" for e, i in $("input.email_selector:checked")
    h += "</form>"
    $("body").append(h)
    RailsHelper.prepRailsForm $("form.email_assign"), '/emails/assign', 'post'
    $("form.email_assign").on 'ajax:complete', ->
      ChainMailboxes.loadMessageList ChainMailboxes.messageContainer(), ChainMailboxes.currentMailboxData().id
    $("form.email_assign").submit()

  init : (messageListContainer) ->
    @messageListContainer = messageListContainer
    ChainMailboxes.applyIndexLayout()
    $("a[data-action='view-mailbox']").live 'click', (evt) ->
      evt.preventDefault()
      ChainMailboxes.loadMessageList messageListContainer, $(@).attr('mailbox-id')

    $("a[data-action='view-email']").live 'click', (evt) ->
      evt.preventDefault()
      window.location = "/emails/"+$(@).attr('email-id')

    $("input.email_selector").live 'change', (evt) ->
      p = $(@).parents('div.message_entry')
      if p.find('input.email_selector').attr('checked')=='checked'
        p.addClass('selected')
      else
        p.removeClass('selected')
      ChainMailboxes.setMessageControls $("div.message_list_inner")

    $("a[data-action='assign-emails']").live 'click', (evt) ->
      evt.preventDefault()
      ChainMailboxes.showAssignPrompt()

    $("a[data-action='clear-email-selection']").live 'click', (evt) ->
      evt.preventDefault()
      $('input.email_selector:checked').removeAttr('checked').change()
