#=require bulk_actions
#=require chain

describe "BulkActions", ->
  describe "submitBulkClassify", ->
    submitCallback = jasmine.createSpy().andReturn(false)
    beforeEach ->
      loadFixtures("basic_form")
      $("#frm").attr('id','frm_bulk')
      $("#frm_bulk").submit(submitCallback)

    it "should set form action", ->
      BulkActions.submitBulkClassify()
      expect($("#frm_bulk").attr('action')).toEqual("/products/bulk_classify.json")

    it "should set form to remote", ->
      BulkActions.submitBulkClassify()
      expect($("#frm_bulk").attr('data-remote')).toEqual("true")

    it "should submit form", ->
      BulkActions.submitBulkClassify()
      expect(submitCallback).toHaveBeenCalled()

    it "should set ajax callback to handleBulkClassify", ->
      BulkActions.submitBulkClassify()
      expect($("#frm_bulk")).toHandleWith('ajax:success',BulkActions.handleBulkClassify)

  describe "handleBulkClassify", ->
    d = loadJSONFixtures("product.json")['product.json']
    beforeEach ->
      spyOn(Chain,'showQuickClassify')

    it "should pass to Chain.showQuickClassify", ->
      BulkActions.handleBulkClassify "xhr", d, "success"
      expect(Chain.showQuickClassify).toHaveBeenCalledWith(d.product,'/products/bulk_update_classifications')

    it "should pass search run id", ->
      loadFixtures("basic_form")
      $("#frm").attr('id','frm_bulk')
      $("#frm_bulk").append("<input type='hidden' name='sr_id' value='5'/>")
      BulkActions.handleBulkClassify "xhr", d, "success"
      expect(Chain.showQuickClassify).toHaveBeenCalledWith(d.product,'/products/bulk_update_classifications',{"sr_id":"5"})

    it "should pass primary keys", ->
      loadFixtures("basic_form")
      $("#frm").attr('id','frm_bulk')
      $("#frm_bulk").append("<input type='hidden' name='pk[0]' value='5'/>")
      $("#frm_bulk").append("<input type='hidden' name='pk[1]' value='6'/>")
      BulkActions.handleBulkClassify "xhr", d, "success"
      expect(Chain.showQuickClassify).toHaveBeenCalledWith(d.product,'/products/bulk_update_classifications',{"pk":["5","6"]})
