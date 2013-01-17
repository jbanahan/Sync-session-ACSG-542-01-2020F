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

  describe "loadAutoClassifications", ->
    it "should call renderAutoClassifications", ->
      spyOn(jQuery,'get')
      Chain.loadAutoClassifications('1234567890',1)
      expect(jQuery.get).toHaveBeenCalledWith('/official_tariffs/auto_classify/1234567890.json',jasmine.any(Function))

    it "should strip non-numerics", ->
      spyOn(jQuery,'get')
      Chain.loadAutoClassifications('1234567i.8A 90',1)
      expect(jQuery.get).toHaveBeenCalledWith('/official_tariffs/auto_classify/1234567890.json',jasmine.any(Function))

  describe "populateAutoClassifications", ->
    it "should fill for multiple countries", ->
      loadFixtures('basic_form')
      $("form").append("<div data-target='auto-class' country='14'></div><div data-target='auto-class' country='234'></div>")
      Chain.populateAutoClassifications("[data-target='auto-class']",loadJSONFixtures('auto_classify.json')['auto_classify.json'])
      expect($("div[data-target='auto-class'][country='14']").html()).toMatch(/desc1/)
      
  describe 'add / fire TariffCallback', ->
    it 'should add callback by country', ->
      x = ""
      cbX = (tNum) ->
        x += 'x'+ tNum
      cbY = (tNum) ->
        x += 'y'+ tNum
      cbZ = (tNum) ->
        x += 'z'+ tNum
      country_id = 10
      Chain.addTariffCallback('valid',country_id,cbX)
      Chain.addTariffCallback('valid',country_id,cbY)
      Chain.addTariffCallback('invalid',country_id,cbZ)
      
      Chain.fireTariffCallbacks('valid',country_id,"ABC")
      expect(x).toEqual('xABCyABC')

  describe 'showQuickClassify', ->
    data = loadJSONFixtures('product.json')['product.json'].product
    beforeEach ->
      $.fx.off = true

    afterEach ->
      $("#mod_quick_classify").remove()

    it 'should create mod if it does not exist', ->
      Chain.showQuickClassify(data,'/x')
      mqc = $("#mod_quick_classify[class*='ui-dialog-content']")
      expect(mqc).toBeVisible()
      frm = mqc.find("form[action='/x'][method='post']")
      expect(frm).toExist()

    it "should write form inputs", ->
      Chain.showQuickClassify(data,'/x')
      expect($("input[name='product[classifications_attributes][0][country_id]'][value='14']")).toExist()
      expect($("input[name='product[classifications_attributes][1][country_id]'][value='234']")).toExist()
      expect($("input[name='product[classifications_attributes][0][tariff_records_attributes][0][hts_1]'][value='1234567890'][country='14']")).toExist()
      expect($("input[name='product[classifications_attributes][1][tariff_records_attributes][0][hts_1]'][value='0987654321'][country='234']")).toExist()

    it "should replace null with blank string", ->
      data.classifications[0].tariff_records[0].hts_1 = null
      Chain.showQuickClassify(data,'/x')
      expect($("input[name='product[classifications_attributes][0][tariff_records_attributes][0][hts_1]'][value='']")).toExist()

    it "should write bulk search_run_id", ->
      Chain.showQuickClassify(data,'/x',{"sr_id":"7"})
      expect($("form input[name='sr_id'][type='hidden'][value='7']")).toExist()

    it "should write bulk primary keys", ->
      Chain.showQuickClassify(data,'/x',{"pk":["7","8","9"]})
      expect($("form input[name='pk[0]'][type='hidden'][value='7']")).toExist()
      expect($("form input[name='pk[1]'][type='hidden'][value='8']")).toExist()
      expect($("form input[name='pk[2]'][type='hidden'][value='9']")).toExist()
    
    it "should not submit form if invalid tariffs", ->
      spyOn(OpenChain,'hasInvalidTariffs').andReturn(true)
      spyOn(window,'alert')
      frm = $("#mod_quick_classify form")
      spyOn(frm,'submit')
      Chain.showQuickClassify(data,'/x',{"pk":["7","8","9"]})
      $("button").each ->
        $(@).click() if $(@).children("span").html()=="Save"
      expect(frm.submit).not.toHaveBeenCalled()
      expect(window.alert).toHaveBeenCalledWith("Please correct or erase all bad tariff numbers.")

    it "should load classifications without tariff records", ->
      data.classifications[0].id = 1
      data.classifications[0].tariff_records = []
      Chain.showQuickClassify(data, '/x')
      
      expect($("input[name='product[classifications_attributes][0][tariff_records_attributes][0][hts_1]']").attr("value")).toEqual("")
      expect($("input[name='product[classifications_attributes][0][id]']").attr("value")).toEqual(""+data.classifications[0].id)
      expect($("input[name='product[classifications_attributes][0][tariff_records_attributes][0][id]']")).not.toExist()
