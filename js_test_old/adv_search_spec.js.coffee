#=require legacy/adv_search

describe 'OCSearch', ->
  describe 'addBulkHandler', ->
    beforeEach ->
      loadFixtures("basic_form")
      $("#frm").append("<button id='blkbtn'>Bulk Button</button>")

    it "should add to bulkButtons", ->
      OCSearch.addBulkHandler("blkbtn","/abc")
      expect(OCSearch.getBulkButtons()[0]).toEqual($("#blkbtn"))

    it "should add click handler", ->
      OCSearch.addBulkHandler("blkbtn","/abc")
      expect($("#blkbtn")).toHandle('click')

    it "should do default callback", ->
      $("#frm").attr("id","frm_bulk")
      submitCallback = jasmine.createSpy().andReturn(false)
      $("#frm_bulk").submit(submitCallback)
      OCSearch.addBulkHandler("blkbtn","/abc")
      $("#blkbtn").click()
      expect(submitCallback).toHaveBeenCalled()

    it "should run alternate callback", ->
      $("#frm").attr("id","frm_bulk")
      submitCallback = jasmine.createSpy().andReturn(false)
      altCallback = jasmine.createSpy().andReturn(false)
      $("#frm_bulk").submit(submitCallback)
      OCSearch.addBulkHandler("blkbtn","/abc",altCallback)
      $("#blkbtn").click()
      expect(submitCallback).not.toHaveBeenCalled()
      expect(altCallback).toHaveBeenCalled()

    it "should call updateBulkForm", ->
      spyOn(OCSearch,'updateBulkForm')
      OCSearch.addBulkHandler("blkbtn","/abc")
      expect(OCSearch.updateBulkForm).toHaveBeenCalled()
      
