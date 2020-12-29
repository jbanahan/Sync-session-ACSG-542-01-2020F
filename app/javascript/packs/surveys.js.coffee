root = exports ? this
root.ChainSurveys =
  applyRankToQuestions : ->
    $(hdn).val(idx) for hdn, idx in $("input[name*='questions_attributes'][name$='[rank]']")
