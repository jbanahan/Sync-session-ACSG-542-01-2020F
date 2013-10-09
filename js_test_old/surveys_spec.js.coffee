#=require surveys

describe 'ChainSurveys', ->
  describe 'applyRankToQuestions', ->
    beforeEach ->
      loadFixtures("basic_form")

    it 'should set rank field in order on page', ->
      $("#frm").append("<input type='hidden' name='survey[questions_attributes][100][rank]' value='2' />")
      $("#frm").append("<input type='hidden' name='survey[questions_attributes][1][rank]' value='' />")
      $("#frm").append("<input type='hidden' name='survey[questions_attributes][50][rank]' value='1' />")
      ChainSurveys.applyRankToQuestions()
      expect($("#frm input[name='survey[questions_attributes][100][rank]']").val()).toEqual('0')
      expect($("#frm input[name='survey[questions_attributes][1][rank]']").val()).toEqual('1')
      expect($("#frm input[name='survey[questions_attributes][50][rank]']").val()).toEqual('2')
