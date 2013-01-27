#=require mailboxes
#=require chain
describe 'ChainMailboxes', ->
  describe 'loadMessageList', ->
    it 'should get messages', ->
      loadFixtures('basic_form')
      spyOn(jQuery,'get')
      ChainMailboxes.loadMessageList $("#div"), 1
      expect(jQuery.get).toHaveBeenCalledWith('/mailboxes/1.json',jasmine.any(Function))

  describe 'renderMessageList', ->
    beforeEach ->
      @data = {'name':'my mailbox','id':1,'emails':[{'subject':'s1','created_at':'2013-01-26T16:22:22-05:00','from':'e1@sample.com','id':1,'assigned_to_id':1},{'subject':'s2','created_at':'2013-01-27T16:22:22-05:00','from':'e2@sample.com','id':2,'assigned_to_id':null}],'users':{1:{'id':1,'full_name':'Joe Friday'}}}
      loadFixtures('basic_form')
      
    it 'should fill list', ->
      ChainMailboxes.renderMessageList $("#div"), @data
      expect($("#div div.message_list_title")).toExist()
      expect($("#div div.message_list_title").html()).toEqual("my mailbox")
      expect($("#div div.users")).toExist()
      expect($("#div div.users div.user_entry[user-id='1']")).toExist()
      expect($("#div div.message_entry").size()).toEqual(2)
      expect($("#div div.message_entry a[data-action='view-email'][email-id='1']")).toExist()
