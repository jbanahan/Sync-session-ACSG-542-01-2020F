#=require bulk_actions
#=require chain

describe "BulkActions", ->
  describe "submitBulkAction", ->
    getSBA = () ->
      $("#submit_bulk_action")

    submitCallback = jasmine.createSpy().andReturn(false)

    beforeEach ->
      setFixtures("<div></div>")
      $("body").on 'submit', 'form', submitCallback
    
    afterEach ->
      $("form").remove()

    it "should create and submit form", ->
      BulkActions.submitBulkAction([1],null,'/a/b','post')
      expect(submitCallback).toHaveBeenCalled()

    it "should set form to remote if ajaxCallback provided", ->
      ajaxAction = () ->
        true
      BulkActions.submitBulkAction([1],null,'/a','post',ajaxAction)
      expect(getSBA().attr('data-remote')).toEqual('true')
      expect(getSBA()).toHandleWith('ajax:success',ajaxAction)
      

    it "should not set form to remote if ajaxCallback not provided", ->
      BulkActions.submitBulkAction [1], null, '/a', 'post'
      expect(getSBA().attr('data-remote')).toBeUndefined()

    it "should set form action", ->
      BulkActions.submitBulkAction [1], null, '/target', 'post'
      expect(getSBA().attr('action')).toEqual('/target')

    it "should include searchId if is a number", ->
      BulkActions.submitBulkAction [1], 7, '/target', 'post'
      expect($("#submit_bulk_action input[type='hidden'][name='sr_id'][value='7']")).toExist()

    it "should not included searchId if not a number", ->
      BulkActions.submitBulkAction [1], null, '/target', 'post'
      expect($("#submit_bulk_action input[type='hidden'][name='sr_id']")).not.toExist()

    it "should include keys if no searchId", ->
      BulkActions.submitBulkAction [1,2], null, '/target', 'post'
      expect($("#submit_bulk_action input[type='hidden'][name='pk[0]'][value='1']")).toExist()
      expect($("#submit_bulk_action input[type='hidden'][name='pk[1]'][value='2']")).toExist()

    it "should not include keys if searchId", ->
      BulkActions.submitBulkAction [1,2], 7, '/target', 'post'
      expect($("#submit_bulk_action input[type='hidden'][name='pk[0]'][value='1']")).not.toExist()

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
      $("#frm").addClass 'bulk_form'
      $(".bulk_form").append("<input type='hidden' name='sr_id' value='5'/>")
      BulkActions.handleBulkClassify "xhr", d, "success"
      expect(Chain.showQuickClassify).toHaveBeenCalledWith(d.product,'/products/bulk_update_classifications',{"sr_id":"5"})

    it "should pass primary keys", ->
      loadFixtures("basic_form")
      $("#frm").addClass 'bulk_form'
      $("#frm").append("<input type='hidden' name='pk[0]' value='5'/>")
      $("#frm").append("<input type='hidden' name='pk[1]' value='6'/>")
      BulkActions.handleBulkClassify "xhr", d, "success"
      expect(Chain.showQuickClassify).toHaveBeenCalledWith(d.product,'/products/bulk_update_classifications',{"pk":["5","6"]})

