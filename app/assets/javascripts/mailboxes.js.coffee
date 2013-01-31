root = exports ? this
root.ChainMailboxes =
  
  currentMailboxData : ->
    @mailboxData

  messageContainer : ->
    @messageListContainer

  currentMessageListOpts : ->
    @messageListOpts

  mailboxContainer : ->
    @mailboxListContainer

  #format the list of mailboxes
  applyIndexLayout : ->

  loadMailboxList : (mailboxListContainer) ->
    $.get '/mailboxes.json', (data) ->
      ChainMailboxes.renderMailboxList mailboxListContainer, data

  renderMailboxList : (mailboxListContainer,data) ->
    renderMailbox = (m) ->
      renderBreakdown = (label,b,isArchived) ->
        renderBreakdownLine = (line) ->
          "<div><a href='#' data-action='view-mailbox' mailbox-id='"+m.id+"' user-id='"+line.user.id+"' "+(if isArchived then 'archived=true' else '')+">"+line.user.full_name+"</a> ("+line.count+")</div>"
        h = "<div class='mailbox_breakdown_label'>"+label+"</div>"
        h += renderBreakdownLine ln for ln in b
        h
      h = "<div class='mailbox_title'>"+m.name+"</div><div class='mailbox_actions'>"
      if m.not_archived.length > 0
        h += renderBreakdown 'Not Archived', m.not_archived, false
      if m.archived.length > 0
        h += renderBreakdown 'Archived', m.archived, true
      h += "</div>"
      h
    h = "<div id='mailbox_accordion'>"
    h += renderMailbox(m) for m in data.mailboxes
    h += "</div>"
    mailboxListContainer.html(h)
    $("#mailbox_accordion").accordion {header:'.mailbox_title'}

  #get the message list from the server and render it
  loadMessageList : (messageListContainer,mailboxId,opts) ->
    @messageListOpts = opts
    messageListContainer.html("Loading...")
    qs = "x=x"
    if opts?
      qs += "&page="+opts.pageId if opts.pageId?
      qs += "&assigned_to="+opts.userId if opts.userId?
      qs += "&archived=true" if opts.archived? && opts.archived
  
    $.get "/mailboxes/"+mailboxId+".json?"+qs, (data) ->
      ChainMailboxes.renderMessageList messageListContainer, data

  reloadMessageList : ->
    ChainMailboxes.loadMessageList $(ChainMailboxes.messageContainer()), ChainMailboxes.currentMailboxData().id, ChainMailboxes.currentMessageListOpts()
    ChainMailboxes.loadMailboxList $(ChainMailboxes.mailboxContainer())

  highlightActiveMessageList: (mailboxId, userId, archived) ->
    $("a[data-action='view-mailbox']").removeClass('active_mailbox')
    $("a[data-action='view-mailbox'][mailbox-id='"+mailboxId+"'][user-id='"+userId+"']"+(if archived then "[archived='true']" else ":not([archived='true'])")).addClass('active_mailbox')

  #show message list on screen
  renderMessageList : (messageListContainer,data) ->
    ChainMailboxes.highlightActiveMessageList data.id, data.selected_user.id, data.archived
    @mailboxData = data
    renderEmail = (e) ->
      h = "<div class='message_entry'><input type='checkbox' value='"+e.id+"' class='email_selector' /><a href='#' data-action='view-email' email-id='"+e.id+"'>"+e.subject+"</a>"
      h += "<div class='message_info'>"+e.from+" | "+Chain.formatJSONDate(e.created_at,true)+"</div>"
      h += "</div>"
      aTo = if e.assigned_to_id then e.assigned_to_id else 0
      messageListContainer.find("div.message_list_inner").append(h)
    renderMessageControls = ->
      h ="<div id='message_controls' style='display:none;'>"
      h += "<div class='count_message'><span id='selected_count'></span> Message<span id='selected_plural'></span> Selected</div>"
      h += "<a href='#' data-action='assign-emails'>Assign</a> | "
      h += "<a href='#' data-action='toggle-email-archive'>Toggle Archive</a> | "
      h += "<a href='#' data-action='clear-email-selection'>Clear</a></div>"
      h
    renderPagination = ->
      h = "<div id='message_nav'>Page "+data.pagination.current_page+" of "+data.pagination.total_pages+"&nbsp;"
      if data.pagination.current_page > 1
        h += "<a href='#' data-action='view-mailbox' mailbox-id='"+data.id+"' page='"+( data.pagination.current_page-1 )+"'"
        h += "user-id='"+data.selected_user.id+"'" if data.selected_user
        h += " >&lt;</a> "
      if data.pagination.current_page < data.pagination.total_pages
        h += "<a href='#' data-action='view-mailbox' mailbox-id='"+data.id+"' page='"+( data.pagination.current_page+1 )+"'"
        h += "user-id='"+data.selected_user.id+"'" if data.selected_user
        h += " >&gt;</a> "
      h += "</div>"
      h
    h = "<div class='message_list_inner' style='display:none;'><div class='message_list_title'>"+data.name+"</div>"
    h += renderMessageControls()
    h += renderPagination()
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

  toggleArchive : () ->
    $("form.email_archive_toggle").remove() #clear any old forms laying around
    h = "<form class='email_archive_toggle' data-remote='true' style='display:none;'>"
    h += "<input type='hidden' name='email["+i+"][id]' value='"+$(e).val()+"' />" for e, i in $("input.email_selector:checked")
    h += "</form>"
    $("body").append(h)
    RailsHelper.prepRailsForm $("form.email_archive_toggle"), '/emails/toggle_archive', 'post'
    $("form.email_archive_toggle").on 'ajax:complete', ->
      ChainMailboxes.reloadMessageList()
    $("form.email_archive_toggle").submit()

  assignEmails : (userId) ->
    $("form.email_assign").remove() #clear any old forms laying around
    h = "<form class='email_assign' data-remote='true' style='display:none;'><input type='hidden' name='user_id' value='"+userId+"'/>"
    h += "<input type='hidden' name='email["+i+"][id]' value='"+$(e).val()+"' />" for e, i in $("input.email_selector:checked")
    h += "</form>"
    $("body").append(h)
    RailsHelper.prepRailsForm $("form.email_assign"), '/emails/assign', 'post'
    $("form.email_assign").on 'ajax:complete', ->
      ChainMailboxes.reloadMessageList()
    $("form.email_assign").submit()

  init : (mailboxListContainer,messageListContainer) ->
    @mailboxListContainer = mailboxListContainer
    @messageListContainer = messageListContainer
    ChainMailboxes.loadMailboxList(mailboxListContainer)
    $("a[data-action='view-mailbox']").live 'click', (evt) ->
      evt.preventDefault()
      opts = {
        userId:$(@).attr('user-id'),
        pageId:$(@).attr('page'),
        archived:$(@).attr('archived')=='true'
      }
      ChainMailboxes.loadMessageList messageListContainer, $(@).attr('mailbox-id'), opts

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

    $("a[data-action='toggle-email-archive']").live 'click', (evt) ->
      evt.preventDefault()
      ChainMailboxes.toggleArchive()
