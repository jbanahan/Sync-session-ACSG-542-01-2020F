#=require open_chain

describe 'OpenChain', ->
  describe 'setAuthToken', ->
    it 'should set token', ->
      OpenChain.setAuthToken 'XX'
      expect(OpenChain.getAuthToken()).toEqual('XX')
  describe 'loadUserList', ->
    it 'should defer to Chain', ->
      spyOn(Chain,'loadUserList')
      OpenChain.loadUserList('x','y')
      expect(Chain.loadUserList).toHaveBeenCalledWith('x','y')
