#=require legacy/open_chain

describe 'OpenChain', ->
  describe 'loadUserList', ->
    it 'should defer to Chain', ->
      spyOn(Chain,'loadUserList')
      OpenChain.loadUserList('x','y')
      expect(Chain.loadUserList).toHaveBeenCalledWith('x','y')
