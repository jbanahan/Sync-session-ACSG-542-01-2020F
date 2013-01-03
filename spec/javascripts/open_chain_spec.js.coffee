#=require open_chain
#=require rails_helper

describe 'OpenChain', ->
  describe 'setAuthToken', ->
    it 'should set token', ->
      OpenChain.setAuthToken 'XX'
      expect(OpenChain.getAuthToken()).toEqual('XX')
    it 'should also set token in Rails Helper', ->
      OpenChain.setAuthToken 'YY'
      expect(RailsHelper.authToken()).toEqual('YY')
  describe 'loadUserList', ->
    it 'should defer to Chain', ->
      spyOn(Chain,'loadUserList')
      OpenChain.loadUserList('x','y')
      expect(Chain.loadUserList).toHaveBeenCalledWith('x','y')
