#=require mailboxes
#=require chain
describe 'ChainMailboxes', ->
  beforeEach ->
    @email_data = {'name':'my mailbox','id':1,'pagination':{'current_page':2,'total_pages':3},'selected_user':{'id':1,'full_name':'Joe Friday'},'emails':[{'subject':'s1','created_at':'2013-01-26T16:22:22-05:00','from':'e1@sample.com','id':1,'assigned_to_id':1},{'subject':'s2','created_at':'2013-01-27T16:22:22-05:00','from':'e2@sample.com','id':2,'assigned_to_id':null}],'users':[{'id':1,'full_name':'Joe Friday'}]}
    @mailbox_data = {'mailboxes':[{'id':1,'name':'M1','not_archived':[{'user':{'id':10,'full_name':'FU'},'count':100}],'archived':[{'user':{'id':20,'full_name':'U2'},'count':2}]}]}
    loadFixtures('basic_form')

  describe 'loadMailboxList', ->
    it 'should get mailboxes', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMailboxList $("#div")
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes.json',jasmine.any(Function))
  describe 'renderMailboxList', ->
    it 'should show mailbox list', ->
      ChainMailboxes.renderMailboxList $("#div"), @mailbox_data
      expect($("#div #mailbox_accordion div.mailbox_title:first")).toHaveText('M1')
      archLink = $("a[mailbox-id='1'][user-id='10']")
      expect(archLink).toExist()
      expect(archLink.html()).toEqual("FU")

  describe 'loadMessageList', ->
    it 'should get messages', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json?x=x',jasmine.any(Function))

    it 'should filter by user', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1, {userId:2}
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json?x=x&assigned_to=2',jasmine.any(Function))

    it 'should filter by archived state', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1, {archived:true}
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json?x=x&archived=true',jasmine.any(Function))

    it 'should filter by page', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1, {pageId:2}
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json?x=x&page=2',jasmine.any(Function))

  describe 'renderMessageList', ->
    it 'should fill list', ->
      ChainMailboxes.renderMessageList $("#div"), @email_data
      expect($("#div div.message_list_title")).toExist()
      expect($("#div div.message_list_title").html()).toEqual("my mailbox")
      expect($("#div div.message_entry").size()).toEqual(2)
      expect($("#div div.message_entry a[data-action='view-email'][email-id='1']")).toExist()

  describe 'toggleArchive', ->
    afterEach ->
      $("form.email_archive_toggle").remove() #clear any old forms laying around

    it 'should call archive toggle', ->
      submitCallback = jasmine.createSpy().andReturn(false)
      $("form[action='/emails/toggle_archive'][method='post']").live('submit',submitCallback)
      ChainMailboxes.renderMessageList $("#div"), @email_data
      $(":checkbox").prop('checked',true)
      ChainMailboxes.toggleArchive()
      expect(submitCallback).toHaveBeenCalled()
      f = $("form[action='/emails/toggle_archive'][method='post']")
      expect(f).toExist()
      expect($("form input[name='email[0][id]'][value='1']:hidden")).toExist()
      expect($("form input[name='email[1][id]'][value='2']:hidden")).toExist()

  describe 'showAssignPrompt', ->
    afterEach ->
      $("#assign_email_container").remove()
    it 'should show modal with users', ->
      ChainMailboxes.renderMessageList $("#div"), @email_data
      ChainMailboxes.showAssignPrompt()
      expect($("#assign_email_container")).toExist()
      expect($("#assign_email_container select option[value='1']")).toExist()

  describe 'assignEmails', ->
    afterEach ->
      $("form.email_assign").remove() #clear any old forms laying around

    it 'should build and submit form', ->
      submitCallback = jasmine.createSpy().andReturn(false)
      $("form[action='/emails/assign'][method='post']").live('submit',submitCallback)
      ChainMailboxes.renderMessageList $("#div"), @email_data
      $(":checkbox").prop('checked',true)
      ChainMailboxes.assignEmails 99 #user_id
      expect(submitCallback).toHaveBeenCalled()
      f = $("form[action='/emails/assign'][method='post']")
      expect(f).toExist()
      expect($("form input[name='email[0][id]'][value='1']:hidden")).toExist()
      expect($("form input[name='email[1][id]'][value='2']:hidden")).toExist()
      expect($("form input[name='user_id'][value='99']:hidden")).toExist()
