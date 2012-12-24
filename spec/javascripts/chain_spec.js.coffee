#=require chain
describe 'Chain', ->
  describe 'loadUserList', ->
    it 'should call default URL', ->
      spyOn(jQuery,'get')
      Chain.loadUserList('x','y')
      expect(jQuery.get).toHaveBeenCalledWith('/users.json',jasmine.any(Function))
      
  describe 'populateUserList', ->
    sel = ''
    data = loadJSONFixtures('users.json')['users.json']
    beforeEach ->
      loadFixtures('basic_form')
      sel = $("#slct")

    it 'should fill select box', ->
      Chain.populateUserList(sel,undefined,data)
      first_opt = sel.find("option[value='1']")
      expect(first_opt.html()).toEqual('Joe User')

    it 'should put users in correct optgroups', ->
      Chain.populateUserList(sel,undefined,data)
      expect(sel.find("optgroup[label='My Company']").find("option[value='1']").html()).toEqual("Joe User")
      expect(sel.find("optgroup[label='My Company']").find("option[value='2']").html()).toEqual("Brian Glick")
      expect(sel.find("optgroup[label='C2']").find("option[value='3']").html()).toEqual("XYZ")

    it 'should set selection', ->
      Chain.populateUserList(sel,2,data)
      expect(sel.find("optgroup[label='My Company']").find("option[value='2'][selected='selected']").html()).toEqual("Brian Glick")
      
