var OCSearch = (function() {
  var allSelected = false;
  var maxObjects;
  var searchRunId;
  var bulkButtons = [];
  var allObjectsMode = false;

  var addSelectionCookie = function(search_run_id,primary_key) {
    var cookie_name = "sr_"+search_run_id;
    var cookie_content = getSelectedCookieVal(search_run_id);
    $.cookie("sr_"+search_run_id,cookie_content+primary_key+"/");
  }
  var removeSelectionCookie = function(search_run_id,primary_key) {
    var cookie_name = "sr_"+search_run_id;
    var pks = getSelectedCookieArray(search_run_id);
    var new_cookie = "";
    var i;
    for(i=0;i<pks.length;i++) {
      if(pks[i]!=primary_key && pks[i].length>0) {
        new_cookie += pks[i]+"/";
      }
    }
    $.cookie(cookie_name,new_cookie)
  }
  var getSelectedCookieVal = function(searchRunId) {
    var r = $.cookie("sr_"+searchRunId);
    return r==null ? "" : r;
  }
  var getSelectedCookieArray = function(searchRunId) {
    var x = getSelectedCookieVal(searchRunId).split("/");
    var y = [];
    for(var i=0;i<x.length; i++) {
      if(x[i].length>0) {
        y.push(x[i]);
      }
    }
    return y;
  }
  var initBulkCheckboxes = function() {
    var pks = getSelectedCookieArray(searchRunId);
    var item;
    for(var i=0;i<pks.length;i++) {
      $("#sel_row_"+pks[i]).attr('checked','checked');
    }
  }

  var rewriteBulkForm = function() { //function here for legacy support
    OCSearch.updateBulkForm();
  }

  var initBulkSelectors = function() {
    $("#result_table").find(":checkbox:not(#chk_sel_all)").click(rewriteBulkForm);
    var selAllBinding = function() {
      $("#result_table").find(":checkbox:not(#chk_sel_all)").unbind('click').attr('checked',(allSelected ? '' : 'checked')).click(rewriteBulkForm);;
      $("#chk_sel_all").unbind('click').attr('checked','').click(selAllBinding);
      allSelected = !allSelected;
      rewriteBulkForm();
    }
    $("#chk_sel_all").click(selAllBinding);
  }

  var initSelectFullList = function() {
    $(".sel_full").live('click',function(ev) {
      ev.preventDefault();
      allObjectsMode = true;
      $("#result_table").find(":checkbox:not(#chk_sel_all)").attr('checked','checked');
      rewriteBulkForm();
    });
    $(".sel_none").live('click',function(ev) {
      ev.preventDefault();
      allObjectsMode = false;
      $.cookie("sr_"+searchRunId,'');
      $("#result_table").find(':checkbox').attr('checked','');
      rewriteBulkForm();
    });
  }

  var initSearchCrits = function() {
    var getDataType = function(f) {
      return f.parents("tr:first").find(".srch_crit_fld option:selected").attr('dtype');
    }
    var numDateVal = function(f) {
      var dt = getDataType(f);
      if(dt=="date" || dt=="datetime") {
        f.datepicker({dateFormat: 'yy-mm-dd'});
      }
      if(dt=="integer" || dt=="decimal" || dt=="fixnum"){
        f.jStepper();
      }
    }
    var relDateVal = function(f) {
      f.jStepper();
    }
    var writeSearchOperators = function(modelField,selected) {
      var dt = getDataType(modelField);
      var h = "";
      if(dt=="date" || dt=="datetime") {
        h += "<option value='eq'>Equals</option>";
        h += "<option value='nq'>Not Equal To</option>";
        h += "<option value='gt'>After</option>";
        h += "<option value='lt'>Before</option>";
        h += "<option value='bda'>Before _ Days Ago</option>";
        h += "<option value='ada'>After _ Days Ago</option>";
        h += "<option value='bdf'>Before _ Days From Now</option>";
        h += "<option value='adf'>After _ Days From Now</option>";
        h += "<option value='pm'>Previous _ Months</option>";
      }
      if(dt=="integer" || dt=="decimal" || dt=="fixnum") {
        h += "<option value='eq'>Equals</option>";
        h += "<option value='nq'>Not Equal To</option>";
        h += "<option value='gt'>Greater Than</option>";
        h += "<option value='lt'>Less Than</option>";
        h += "<option value='sw'>Starts With</option>";
        h += "<option value='ew'>Ends With</option>";
        h += "<option value='co'>Contains</option>";
        h += "<option value='in'>One Of</option>";
      }
      if(dt=="string" || dt=="text") {
        h += "<option value='eq'>Equals</option>";
        h += "<option value='nq'>Not Equal To</option>";
        h += "<option value='sw'>Starts With</option>";
        h += "<option value='ew'>Ends With</option>";
        h += "<option value='co'>Contains</option>";
        h += "<option value='nc'>Doesn't Contain</option>";
        h += "<option value='in'>One Of</option>";
      }
      h += "<option value='null'>Is Empty</option>";
      h += "<option value='notnull'>Is Not Empty</option>";
      var op = modelField.parents("tr:first").find(".srch_crit_oper");
      op.html(h);
      op.val(selected);
      op.change();
    }
    var validations = {
      gt:numDateVal,
      lt:numDateVal,
      eq:numDateVal,
      nq:numDateVal,
      sw:numDateVal,
      ew:numDateVal,
      co:numDateVal,
      ada:relDateVal,
      adf:relDateVal,
      bda:relDateVal,
      bdf:relDateVal,
      pm:relDateVal,
      'null':function(f) {f.hide();},
      'notnull':function(f) {f.hide()}
    }
    var bindValueValidations = function(tr) {
      var op = tr.find(".srch_crit_oper");
      var vField = tr.find(".srch_crit_value");
      var opVal = op.val();
      var tagName = vField[0].nodeName.toLowerCase();
      if(opVal=='in' && tagName!='textarea') {
        vField.replaceWith("<textarea class='srch_crit_value' name='"+vField.attr('name')+"' cols='30' rows='5' id='"+vField.attr('id')+"' />");
        return;
      } else if (opVal!='in' && tagName=='textarea') {
        vField.replaceWith("<input type='text' size='30' id='"+vField.attr('id')+"' name='"+vField.attr('name')+"' class='srch_crit_value' />")
      }
      vField.unbind(); //remove bindings
      vField.show();
      vField.val('');
      vField.datepicker('destroy');
      var v = validations[op.val()]
      if(v) {
        v(vField);
      }
    }
    $(".srch_crit_oper").live('change',function() {
      bindValueValidations($(this).parents("tr:first"));
    });
    $(".srch_crit_fld").live('change',function() {
      writeSearchOperators($(this));
    });
  }

  var initRowDoubleClick = function() {
    $(".search_row").dblclick(function() {
      $(this).find(".double_click_action").each(function() {
        window.location = $(this).attr("href");
      });
    });
    $(".search_row").find("a").dblclick(function(evt) {evt.stopPropagation();}) //prevent an accidental double-click on a link from bubbling up to the row
  }
  var initSave = function(parentHash) {
    $("#btn_setup_save").click(function() {
      var coluids = []
      $("#used_columns option").each(function () {
        coluids.push($(this).attr("value"));
      });
      var f = $("#frm_current_search");
      var i,h;
      for(i=0;i<coluids.length;i++) {
        if(coluids[i].length>0) {
          var h = "<input type='hidden' name='"+parentHash+"[search_columns_attributes]["+i+"][rank]' value='"+i+"' />";
          h = h + "<input type='hidden' name='"+parentHash+"[search_columns_attributes]["+i+"][model_field_uid]' value='"+coluids[i]+"' />";
          f.append(h);
        }
      }
      var srt_uids = []
      $("#used_sorts option").each(function() {
        srt_uids.push([$(this).attr("value"),$(this).attr("ord")]);
      });
      for(i=0;i<srt_uids.length;i++) {
        var h = "<input type='hidden' name='"+parentHash+"[sort_criterions_attributes]["+i+"][rank]' value='"+i+"' />";
        h = h + "<input type='hidden' name='"+parentHash+"[sort_criterions_attributes]["+i+"][model_field_uid]' value='"+srt_uids[i][0]+"' />";
        h = h + "<input type='hidden' name='"+parentHash+"[sort_criterions_attributes]["+i+"][descending]' value='"+(srt_uids[i][1]=="a" ? "false" : "true")+"' />";
        f.append(h);
      }
      f.submit();
    });
  }
  var initColumnSelectors = function() {
    $("#use_sort,#remove_sort").click(function(event) {
      var id = $(event.target).attr("id");
      var selectFrom = id == "use_sort" ? "#unused_sorts" : "#used_sorts";
      var moveTo = id == "use_sort" ? "#used_sorts" : "#unused_sorts";
      var selectedItems = $(selectFrom + " :selected").toArray();
      if(id=="use_sort") {
        $(selectFrom + " :selected").each(function() {
          $(this).html($(this).html()+" [A > Z]");
          $(this).attr('ord','a');
        });
      } else {
        $(selectFrom + " :selected").each(function() {
          $(this).html($(this).html().substring(0,$(this).html().length-11));
        });
      }
      $(moveTo).append(selectedItems);
      selectedItems.remove;
    });
    $("#used_sorts_up").click(function(ev) {
      ev.preventDefault();
      move_list_item('up',$("#used_sorts"));
    });
    $("#used_sorts_down").click(function(ev) {
      ev.preventDefault();
      move_list_item('down',$("#used_sorts"));
    });
    $("#used_sorts_reverse").click(function(ev) {
      ev.preventDefault();
      $("#used_sorts :selected").each(function() {
        var ord = $(this).attr('ord');
        $(this).attr('ord',ord=='a' ? 'd' : 'a');
        var label = ord=='a' ? " [Z > A]" : " [A > Z]"
        label = $(this).html().substring(0,$(this).html().length-11) + label;
        $(this).html(label);
      });
    });
   
    $("#add_blank").click(function(ev) {
      $("#used_columns").append("<option value='_blank'>[Blank]</option>");
    });
    $("#use_column,#remove_column").click(function(event) {
      event.preventDefault();
      var id = $(event.target).attr("id");
      var selectFrom = id == "use_column" ? "#unused_columns" : "#used_columns";
      var moveTo = id == "use_column" ? "#used_columns" : "#unused_columns";
      var selectedItems = $(selectFrom + " :selected").toArray();
      $(moveTo).append(selectedItems);
      selectedItems.remove;
    });
    $("#used_columns_up").click(function(ev) {
      ev.preventDefault();
      move_list_item('up',$("#used_columns"));
    });
    $("#used_columns_down").click(function(ev) {
      ev.preventDefault();
      move_list_item('down',$("#used_columns"));
    });
  }

  var initActionButtons = function(search_url,parentHash) {
    if(search_url.length > 0) {
      $("#mod_new_name").dialog({autoOpen:false,title:"Save As New",
        buttons:{"Save":function() {
          window.location = search_url+'/copy?new_name='+escape($("#txt_new_name").val());
        },"Cancel":function() {$("#mod_new_name").dialog('close');}
        }
      });
      $("#btn_setup_copy").click(function() {
        $("#txt_new_name").val("Copy of "+$("#current_name").val());
        $("#mod_new_name").dialog('open');
      });
      $("#btn_setup_delete").click(function() {
        $("#mod_delete").dialog('open');
      });
      $("#mod_delete").dialog({autoOpen:false,width:"auto",buttons:{
          "Yes":function() {
            $("#real_delete_button").parents("form.button_to").submit();
          },
          "No":function() {
            $("#mod_delete").dialog('close');
          }
      }});
      $("#mod_give_to").dialog({autoOpen:false,width:'auto',title:"Give Copy",
          buttons:{Give:function() {
            var val = $("#give_user_list").val();
            if(isNaN(val)) {
              window.alert("You must select a user to give the report to.");
            } else {
              window.location = search_url+'/give?other_user_id='+val;
            }
          },Cancel:function() {$("#mod_give_to").dialog('close');}
          }
      });
      $("#btn_give_to").click(function(evt) {  
        OpenChain.loadUserList($("#give_user_list"),"");
        $("#mod_give_to").dialog('open');
      });
    }
    $("#mod_schedule").dialog({autoOpen:false,width:'auto',title:"Search Schedule",
      buttons:{Update:function() {
        var k = $("#sd_key").val();
        if(k.length>0) {
          var c = $('.sch_key[value="'+k+'"]').parents('.sch_data_cont');
          removeSchedule(c)
        }
        writeScheduleContainer($("#sched_list"),readScheduleInterface(),parentHash);
        $("#mod_schedule").dialog('close');
      }}
    });
    $("#add_schedule").click(function(ev) {
      ev.preventDefault();
      writeScheduleInterface(newSchedule());
      $("#mod_schedule").dialog('open');
    });
    applyScheduleHooks();
  }
    
  return {
    init: function(max_objects,search_run_id,search_url,parentHash) {
      $("#search_setup").tabs();
      maxObjects = max_objects;
      searchRunId = search_run_id;
      initColumnSelectors();
      initSave(parentHash);
      $("#frm_bulk").attr('action','');
      initBulkCheckboxes();
      initBulkSelectors();
      initSelectFullList();
      initRowDoubleClick();
      initActionButtons(search_url,parentHash);
    },
    initSearchCriterions: function() {
      initSearchCrits();                      
    },
    updateBulkForm: function() {
      var checked = $("#result_table").find(":checked");
      var selectedIds = []; 
      var cookieItems;
      var totalCheckboxes = $("#result_table").find(":checkbox:not(#chk_sel_all)").length;
      var msg;
      if(allObjectsMode && checked.length==$("#result_table").find(":checkbox:not(#chk_sel_all)").length) {
        $("#div_bulk_content").html("<input type='hidden' name='sr_id' value='"+searchRunId+"' />");
        $("#bulk_message").html("All "+maxObjects+" items selected.")
      } else {
        allObjectsMode = false;
        $("#div_bulk_content").html("");
        $("#result_table").find(":checkbox:not(#chk_sel_all)").each(function(index, item) {
          removeSelectionCookie(searchRunId,$(item).attr('pk'));
          if($(item).is(':checked')) {
            addSelectionCookie(searchRunId,$(item).attr('pk'));
          }
        });
        cookieItems = getSelectedCookieArray(searchRunId);
        for(var x=0;x<cookieItems.length;x++) {
          $("#div_bulk_content").append("<input type='hidden' name='pk["+x+"]' value='"+cookieItems[x]+"' />"); 
        }
        for(var x=0;x<bulkButtons.length;x++) {
          if(cookieItems.length) {
            bulkButtons[x].show();
          } else {
            bulkButtons[x].hide();
          }
        }
        if(cookieItems.length>0) {
          msg = cookieItems.length+" selected ";
          if(cookieItems.length < maxObjects) {
            msg += " | <a href='#' class='sel_full'>Select all "+maxObjects+"</a>";
          }
          msg += " | <a href='#' class='sel_none'>Clear</a>";
        } else {
          msg = "&nbsp;";
        }
        $("#bulk_message").html(msg);
      }
    },
    //partially tested (updateBulkForm not tested)
    addBulkHandler: function(button_name,form_path,clickCallback) {
      var callback, b;
      callback = clickCallback ? clickCallback : function() {
        $("#frm_bulk").removeAttr('data-remote'); //default is non-ajax event
        $("#frm_bulk").attr('action',form_path).submit();
      }
      b = $("#"+button_name);
      bulkButtons.push(b);
      b.click(callback);
      OCSearch.updateBulkForm();
    },
    //tested
    getBulkButtons: function() {
      return bulkButtons
    },
    showSetup: function() {
      $("#search_setup_outer").show("blind", { direction: "vertical" }, 500)
      $("#show_srch_setup").hide();
      $("#hide_srch_setup").show();
      $.post('/search_setups/sticky_open');
    },
    hideSetup: function() {
      $("#search_setup_outer").hide("blind", { direction: "vertical" }, 500)
      $("#hide_srch_setup").hide();
      $("#show_srch_setup").show();
      $.post('/search_setups/sticky_close');
    },
    addSearchCriterion: function(parentTable,parentObject,fieldList,m,field,operator,value,id,canDelete) {
      var h = "<tr class='sp_row'><td>";
        if(id) {
          h += "<input id='"+parentObject+"_search_criterions_attributes_"+m+"_id' name='"+parentObject+"[search_criterions_attributes]["+m+"][id]' type='hidden' value='"+id+"'>";
        }
        h += "<select id='"+parentObject+"_search_criterions_attributes_"+m+"_model_field_uid' name='"+parentObject+"[search_criterions_attributes]["+m+"][model_field_uid]' class='srch_crit_fld'>";
        for(var i=0;i<fieldList.length;i++) {
          h = h + "<option value='"+fieldList[i].uid+"' dtype='"+fieldList[i].dtype+"'>"+fieldList[i].label+"</option>";
        }
        h = h + "</select></td>";
        h = h + "<td><select id='"+parentObject+"_search_criterions_attributes_"+m+"_operator' name='"+parentObject+"[search_criterions_attributes]["+m+"][operator]' class='srch_crit_oper'>";
        h = h + "</select></td><td><"+(operator=='in' ? "textarea rows='4' cols='30'" : "input size='30' type='text'")+" id='"+parentObject+"_search_criterions_attributes_"+m+"_value' name='"+parentObject+"[search_criterions_attributes]["+m+"][value]' class='srch_crit_value' /></td>";
        if(canDelete) {
          h = h + "<td><input class='sp_destroy' id='"+parentObject+"_search_criterions_attributes_"+m+"__destroy' name='"+parentObject+"[search_criterions_attributes]["+m+"][_destroy]' type='hidden' value='false' /><a href='#' class='sp_remove'><img src='/images/x.png' title='remove' /></a></td></tr>";
        }
      parentTable.append(h);
      var row = parentTable.find("tr:last");
      var mf = row.find(".srch_crit_fld");
      if(field) {
        mf.val(field);
      }
      mf.change();
      if(operator) {
        row.find(".srch_crit_oper").val(operator);
        row.find(".srch_crit_oper").change();
      }
      if(value) {
        row.find(".srch_crit_value").val(value);
      }
    },
    setDayCheckboxes: function() {
      if($("#sd_dom").val().length>0) {
        $(".day_chk").parents("tr").hide();
      } else {
        $(".day_chk").parents("tr").show();
      }
    }
  };
})();
function getDay(container,abbreviation) {
  return container.children(".sch_"+abbreviation).val()=="true"
}
function applyScheduleHooks() {
  $(".sched_remove").click(function(ev) {
    ev.preventDefault();
    removeSchedule($(this).parents(".sch_data_cont"));
  });
  $(".sched_edit").click(function(ev) {
    ev.preventDefault();
    var r = readScheduleContainer($(this).parents(".sch_data_cont"));
    writeScheduleInterface(r);
    $("#mod_schedule").dialog('open');
  });
  $("#sd_dom").change(function() {
    OCSearch.setDayCheckboxes();
  });
}
function newSchedule() {
  var rv = new Object();
  rv.key = "";
  rv.email = "";
  rv.hour = "0";
  rv.dom = "";
  rv.mon = false;
  rv.tue = false;
  rv.wed = false;
  rv.thu = false;
  rv.fri = false;
  rv.sat = false;
  rv.sun = false;
  rv.ftpsvr = "";
  rv.ftpusr = "";
  rv.ftppass = "";
  rv.ftpfldr = "";
  rv.id = "";
  rv.frmt = "csv";
  return rv;
}
function findScheduleContainerByKey(k) {
  return $('.sch_key[value="'+k+'"]').parents('.sch_data_cont');
}
function removeSchedule(container) {
  container.children(".sch_destroy").val("true");
  container.hide();
}
function readScheduleContainer(c) {
  var rv = new Object();
  rv.key = c.children(".sch_key").val();
  rv.email = c.children(".sch_email").val();
  rv.hour = c.children(".sch_hr").val();
  rv.dom = c.children(".sch_dom").val(); 
  rv.mon = getDay(c,"mon");
  rv.tue = getDay(c,"tue");
  rv.wed = getDay(c,"wed");
  rv.thu = getDay(c,"thu");
  rv.fri = getDay(c,"fri");
  rv.sat = getDay(c,"sat");
  rv.sun = getDay(c,"sun");
  rv.ftpsvr = c.children(".sch_ftpsvr").val();
  rv.ftpusr = c.children(".sch_ftpusr").val();
  rv.ftppass = c.children(".sch_ftppass").val();
  rv.ftpfldr = c.children(".sch_ftpfldr").val();
  rv.id = c.children(".sch_id").val();
  rv.frmt = c.children(".sch_frmt").val();
  return rv;
}
function writeScheduleContainer(container,rv,parentHash) {
  if((rv.mon || rv.tue || rv.wed || rv.thu || rv.fri || rv.sat || rv.sun || rv.dom) && 
      rv.email || rv.ftpsvr) {
    var id = new Date().getTime();
    var ssa = parentHash+"[search_schedules_attributes]["+id+"]";
    var r = "<li class='sch_data_cont'>";
    r += rv.mon ? "Monday, " : "";
    r += rv.tue ? "Tuesday, " : "";
    r += rv.wed ? "Wednesday, " : "";
    r += rv.thu ? "Thursday, " : "";
    r += rv.fri ? "Friday, " : "";
    r += rv.sat ? "Saturday, " : "";
    r += rv.sun ? "Sunday, " : "";
    if(r.length > 26) {
      //trim trailing comma
      r = r.substr(0,r.length-2);
    }
    r += rv.dom ? "Day "+rv.dom+" of the month " : "";
    var ftp_lbl = (rv.ftpsvr && rv.ftpsvr.length > 0) ? "FTP: "+rv.ftpsvr : "";
    r += " at "+rv.hour+":00 to "+rv.email+" "+ftp_lbl+" - <a href='#' class='sched_edit'>Edit</a> | <a href='#' class='sched_remove'>Remove</a>";
    r += "<input class='sch_dom' name='"+ssa+"[day_of_month]' type='hidden' value='"+rv.dom+"'/>";
    r += "<input class='sch_mon' name='"+ssa+"[run_monday]' type='hidden' value='"+rv.mon+"'/>";
    r += "<input class='sch_tue' name='"+ssa+"[run_tuesday]' type='hidden' value='"+rv.tue+"'/>";
    r += "<input class='sch_wed' name='"+ssa+"[run_wednesday]' type='hidden' value='"+rv.wed+"'/>";
    r += "<input class='sch_thu' name='"+ssa+"[run_thursday]' type='hidden' value='"+rv.thu+"'/>";
    r += "<input class='sch_fri' name='"+ssa+"[run_friday]' type='hidden' value='"+rv.fri+"'/>";
    r += "<input class='sch_sat' name='"+ssa+"[run_saturday]' type='hidden' value='"+rv.sat+"'/>";
    r += "<input class='sch_sun' name='"+ssa+"[run_sunday]' type='hidden' value='"+rv.sun+"'/>";
    r += "<input class='sch_hr' name='"+ssa+"[run_hour]' type='hidden' value='"+rv.hour+"'/>";
    r += "<input class='sch_email' name='"+ssa+"[email_addresses]' type='hidden' value='"+rv.email+"'/>";
    r += "<input class='sch_frmt' name='"+ssa+"[download_format]' type='hidden' value='"+rv.frmt+"'/>";
    if(rv.ftpsvr) {
      r += "<input class='sch_ftpsvr' name='"+ssa+"[ftp_server]' type='hidden' value='"+rv.ftpsvr+"'/>";
    }
    if(rv.ftpusr) {
      r += "<input class='sch_ftpusr' name='"+ssa+"[ftp_username]' type='hidden' value='"+rv.ftpusr+"'/>";
    }
    if(rv.ftppass) {
      r += "<input class='sch_ftppass' name='"+ssa+"[ftp_password]' type='hidden' value='"+rv.ftppass+"'/>";
    }
    if(rv.ftpfldr) {
      r += "<input class='sch_ftpfldr' name='"+ssa+"[ftp_subfolder]' type='hidden' value='"+rv.ftpfldr+"'/>";
    }
    r += "<input class='sch_destroy' name='"+ssa+"[_destroy]' type='hidden' value='' />";
    r += "<input class='sch_key' type='hidden' name='ignore_key' value='"+id+"' />";
    r += "</li>";
    container.append(r); 
    applyScheduleHooks();
  }
}
function readScheduleInterface() {
  var rv = new Object();
  rv.email = $("#sd_email").val();
  rv.hour = $("#sd_hr").val();
  rv.dom = $("#sd_dom").val();
  rv.mon = $("#sd_mon:checked").length>0;
  rv.tue = $("#sd_tue:checked").length>0;
  rv.wed = $("#sd_wed:checked").length>0;
  rv.thu = $("#sd_thu:checked").length>0;
  rv.fri = $("#sd_fri:checked").length>0;
  rv.sat = $("#sd_sat:checked").length>0;
  rv.sun = $("#sd_sun:checked").length>0;
  rv.ftpsvr = $("#sd_ftpsvr").val();
  rv.ftpusr = $("#sd_ftpusr").val();
  rv.ftppass = $("#sd_ftppass").val();
  rv.ftpfldr = $("#sd_ftpfldr").val();
  rv.id = $("#sd_id").val();
  rv.key = $("#sd_key").val();
  rv.frmt = $("#sd_frmt").val();
  return rv; 
}
function writeScheduleInterface(s) {
  $("#sd_key").val(s.key);
  $("#sd_id").val(s.id);
  $("#sd_email").val(s.email);
  $("#sd_hr").val(s.hour);
  $("#sd_dom").val(s.dom);
  $("#sd_mon").attr('checked',s.mon);
  $("#sd_tue").attr('checked',s.tue);
  $("#sd_wed").attr('checked',s.wed);
  $("#sd_thu").attr('checked',s.thu);
  $("#sd_fri").attr('checked',s.fri);
  $("#sd_sat").attr('checked',s.sat);
  $("#sd_sun").attr('checked',s.sun);
  $("#sd_ftpsvr").val(s.ftpsvr);
  $("#sd_ftpusr").val(s.ftpusr);
  $("#sd_ftppass").val(s.ftppass);
  $("#sd_ftpfldr").val(s.ftpfldr);
  $("#sd_frmt").val(s.frmt);
  OCSearch.setDayCheckboxes();
}
function submitForm() {
}
function move_list_item(direction,list) {
  var selectedItems = $("#"+list.attr("id")+" :selected");
  if(direction=='down') {
    $($("#"+list.attr("id")+" :selected").get().reverse()).each(function() {
      $(this).next("option").after($(this)); 
    });
  } else {
    $("#"+list.attr("id")+" :selected").each(function() {
      $(this).prev("option").before($(this));
    });
  }
}

function updateShowAllColumnsLink() {
  var div_show_all_columns = $('#show_all_columns');
  hiddenColumnsCookie = $.cookie("hiddenColumns");
  if (null == hiddenColumnsCookie) {
    div_show_all_columns.html("Click Headings To Hide Columns");
  } else {
    div_show_all_columns.html("<a href='#' id='show_all_columns'>Show all columns</a>");
  }
}

function hideColumn(col) {
  hiddenColumnsCookie = $.cookie("hiddenColumns");
  if (hiddenColumnsCookie == null) {
    $.cookie("hiddenColumns", col);
  } else {
    hiddenColumnsCookie += ";" + col;
    $.cookie("hiddenColumns", hiddenColumnsCookie);
  }
  $('#result_table td:nth-child(' + col + '),th:nth-child(' + col + ')').fadeOut();
  updateShowAllColumnsLink();
}

function processHiddenColumns(showAllColumns) {
  hiddenColumnsCookie = $.cookie("hiddenColumns");
  if (hiddenColumnsCookie != null) {
    var cols = hiddenColumnsCookie.split(";");

    for (var i=0; i < cols.length; ++i) {
      if (true == showAllColumns) {
        $('#result_table td:nth-child(' + cols[i] + '),th:nth-child(' + cols[i] + ')').fadeIn();
      } else {
       $('#result_table td:nth-child(' + cols[i] + '),th:nth-child(' + cols[i] + ')').fadeOut();
      }
    };

    if (true == showAllColumns) {
      $.cookie("hiddenColumns", null);
    }
  }
  updateShowAllColumnsLink();
}
