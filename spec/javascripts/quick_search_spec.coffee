describe 'OCQuickSearch', ->
  describe 'byModule', ->
    it 'should getJSON', ->
      spyOn(jQuery,'getJSON')
      spyOn(OCQuickSearch,'writeModuleResponse')

      OCQuickSearch.byModule('Entry','abc')

      expect(jQuery.getJSON).toHaveBeenCalledWith('/quick_search/by_module/Entry?v=abc',OCQuickSearch.writeModuleResponse)

  describe 'writeModuleResponse', ->
    it 'should find outer div and write html', ->
      cardResponses = ['A','B']
      spyOn(OCQuickSearch,'makeCard').andCallFake ->
        cardResponses.pop()

      divWrap = jasmine.createSpyObj('div',['html'])
      spyOn(OCQuickSearch,'findDivWrapper').andReturn(divWrap)

      v1 = {a: 'x'}
      v2 = {c: 'd'}
      fields = {a: 'b'}
      resp = {
        qs_result: {
          module_type:'Entry'
          fields: fields
          vals: [v1,v2]
          search_term:'zz'
        }
      }

      OCQuickSearch.writeModuleResponse(resp)

      expect(OCQuickSearch.makeCard).toHaveBeenCalledWith(fields,v1,'zz')
      expect(OCQuickSearch.makeCard).toHaveBeenCalledWith(fields,v2,'zz')
      expect(divWrap.html).toHaveBeenCalledWith('BA')