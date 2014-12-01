describe "OCSearchTemplates", () ->
  describe "extractSelectedTemplateIds", () ->
    it "should create an array of id numbers based on the checked checkboxes", () ->
      makeCheckbox = (checked,val) ->
        isChecked = checked
        {
          is: (x) ->
            throw "expected x to be \":checked\"" unless x==":checked"
            isChecked
          attr: (x) ->
            throw "expected x to be \"data-template-id\"" unless x=="data-template-id"
            val
        }
      boxes = [
        makeCheckbox(true,'7'),
        makeCheckbox(false,'8'),
        makeCheckbox(true,'9')
      ]
      expect(OCSearchTemplates.extractSelectedTemplateIds(boxes)).toEqual ['7','9']

