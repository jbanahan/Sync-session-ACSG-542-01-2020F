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
      spyOn(OCQuickSearch,'makeCard').and.callFake ->
        cardResponses.pop()

      divWrap = jasmine.createSpyObj('div',['html'])
      spyOn(OCQuickSearch,'findDivWrapper').and.returnValue(divWrap)

      fields = {a: 'b'}
      val1 = {a: 'x'}
      val2 = {c: 'd'}
      extraField = {h: 'i'}
      extraVal = {'1': {f: 'g'}}
      att = {a: 's'}
      business_validation = {b: 'f'}
      resp = {
        qs_result: {
          module_type:'Entry'
          fields: fields
          vals: [val1,val2]
          extra_fields: extraField
          extra_vals: extraVal
          attachments: att
          business_validation_results: business_validation
          search_term:'zz'
        }
      }

      OCQuickSearch.writeModuleResponse(resp)

      expect(OCQuickSearch.makeCard).toHaveBeenCalledWith(fields,val1, extraField, extraVal, att, business_validation, 'zz')
      expect(OCQuickSearch.makeCard).toHaveBeenCalledWith(fields,val2, extraField, extraVal, att, business_validation, 'zz')
      expect(divWrap.html).toHaveBeenCalledWith('BA')
