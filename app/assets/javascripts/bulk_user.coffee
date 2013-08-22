root = exports ? this
root.ChainBulkUser =
  preview: (companyId,data,target) ->
    $.post("/companies/"+companyId+"/users/preview_bulk_upload",{bulk_user_csv:data}).done((resp) ->
      target.html("<tr><td colspan='5'>Preview loading</td></tr>")
      h = ""
      if resp.results.length == 0
        h += "<tr><td colspan='5'>No results returned</td></tr>"
      for usr in resp.results
        h += "<tr><td>"+usr.username+"</td><td>"+usr.email+"</td><td>"+usr.first_name+"</td><td>"+usr.last_name+"</td><td>"+usr.password+"</td></tr>"
      target.html(h)
    ).fail((xhr,status) ->
      if xhr.status == 400
        error = $.parseJSON(xhr.responseText).error
        target.html("<tr><td colspan='5' class='error-text'>"+error+"</td></tr>")
      else
        target.html("<tr><td colspan='5' class='error-text'>Server error.  Please contact support.</td></tr>")
    )
