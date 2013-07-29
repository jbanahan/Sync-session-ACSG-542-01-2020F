root = exports ? this
root.ChainSurveyResponse =
  contactGood : false
  respTrackGood : false

  initLocalStorage : (responseId,lastLogged) ->
    return if typeof(Storage)=="undefined"
    storedLastLogged = localStorage['survey-response-'+responseId+'-logged']
    loadCache = (storedLastLogged == lastLogged)
    localStorage['survey-response-'+responseId+'-logged'] = lastLogged
    $('textarea.a_opt').each(() ->
      if loadCache
        $(@).val localStorage['survey-answer-comm-'+$(@).attr('answer_id')]
      else
        localStorage.removeItem 'survey-answer-comm-'+$(@).attr('answer_id')
      $(@).on('keyup',() ->
        localStorage['survey-answer-comm-'+$(@).attr('answer_id')] = $(@).val()
      )
    )
    $('select.multchoice').each(() ->
      if loadCache
        $(@).val localStorage['survey-answer-mult-'+$(@).attr('answer_id')]
      else
        localStorage.removeItem 'survey-answer-mult-'+$(@).attr('answer_id')
      $(@).on('change',() ->
        localStorage['survey-answer-mult-'+$(@).attr('answer_id')] = $(@).val()
      )
    )

  updateResponseTrack: ->
    quests = $("div.question")
    q_cnt = quests.length
    g_cnt = 0
    quests.each((i,e) ->
      q = $(e)
      pass = false
      if(q.attr('answered')=='y')
        g_cnt++
      else
        $(e).children(".a_opt, .a_fil").each((j,x) ->
          if(!pass && $(x).val().length > 0)
            pass = true
            g_cnt++
        )
    )
    $("#answr_trk").html(g_cnt+" of "+q_cnt+" questions answered.")
    @.respTrackGood = (g_cnt==q_cnt)
    ChainSurveyResponse.setSubmit()
  
  contactCheck: () ->
    pass = true
    $(".creq").each( () ->
      lPass = $(@).val().length > 0
      if(pass)
        pass = lPass
      
      if(!lPass)
        $(@).addClass('error')
      else
        $(@).removeClass('error')
      
    )
    @.contactGood = pass
    ChainSurveyResponse.setSubmit()
  
  addAttachment: (link,uploadedById,answerIndex) ->
    mid = new Date().getTime()
    prefix = "survey_response[answers_attributes]["+answerIndex+"][attachments_attributes]["+mid+"]" 
    h = "<div class='a_line'>"
    h += "<input type='hidden' name='"+prefix+"[attachable_type]' value='Answer'/>"
    h += "<input type='hidden' name='"+prefix+"[uploaded_by_id]' value='"+uploadedById+"'/>"
    h += "<input type='file' class='a_fil' name='"+prefix+"[attached]'>"
    h += " - <a href='#' class='a_rem'>Remove</a>"
    h += "</div>"
    link.before(h)

  setSubmit: ->
    if(@.contactGood && @.respTrackGood)
      $("#btn_submit").show()
    else
      $("#btn_submit").hide()
    

  filter: () ->
    warnMsg = "Showing responses for: "
    $("div.question").hide()
    $("input.r_filter:checked").each( () ->
      val =$(this).val()
      warnLbl = val.length > 0 ? val : "Not Rated"
      $("div.question[rating='"+val+"']").slideDown()
      warnMsg += warnLbl+", "
    )
    if(warnMsg=="Showing responses for: ")
      $("#filter_warn").hide()
    else
      warnMsg = warnMsg.substr(0,warnMsg.length-2)
      $("#filter_warn").html(warnMsg)
      $("#filter_warn").show()
    
