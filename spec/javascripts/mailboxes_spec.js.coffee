#=require mailboxes
#=require chain
describe 'ChainMailboxes', ->
  beforeEach ->
    @data = {'name':'my mailbox','id':1,'filtered_user':{'id':1,'full_name':'Joe Friday'},'emails':[{'subject':'s1','created_at':'2013-01-26T16:22:22-05:00','from':'e1@sample.com','id':1,'assigned_to_id':1},{'subject':'s2','created_at':'2013-01-27T16:22:22-05:00','from':'e2@sample.com','id':2,'assigned_to_id':null}],'users':[{'id':1,'full_name':'Joe Friday'}]}
    loadFixtures('basic_form')

  describe 'loadMessageList', ->
    it 'should get messages', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json',jasmine.any(Function))

    it 'should filter by user', ->
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1, 2
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json?assigned_to=2',jasmine.any(Function))

  describe 'renderMessageList', ->
      
    it 'should fill list', ->
      ChainMailboxes.renderMessageList $("#div"), @data
      expect($("#div div.message_list_title")).toExist()
      expect($("#div div.message_list_title").html()).toEqual("my mailbox")
      expect($("#div div.message_entry").size()).toEqual(2)
      expect($("#div div.message_entry a[data-action='view-email'][email-id='1']")).toExist()

  describe 'showAssignPrompt', ->
    afterEach ->
      $("#assign_email_container").remove()
    it 'should show modal with users', ->
      ChainMailboxes.renderMessageList $("#div"), @data
      ChainMailboxes.showAssignPrompt()
      expect($("#assign_email_container")).toExist()
      expect($("#assign_email_container select option[value='1']")).toExist()

  describe 'assignEmails', ->
    it 'should build and submit form', ->
      dont_submit = ->
        false
      spyOn(dont_submit)
      $("form").submit(dont_submit)
      ChainMailboxes.renderMessageList $("#div"), @data
      ChainMailboxes.assignEmails 99 #user_id
      expect(dont_submit).toHaveBeenCalled
      f = $("form[action='/emails/assign'][method='post']")
      expect(f).toExist()
      expect($("form input[name='email[0][id]'][value='1']:hidden")).toExist()
      expect($("form input[name='email[1][id]'][value='2']:hidden")).toExist()
      expect($("form input[name='user_id'][value='1']:hidden")).toExist()
