var OCSearch = (function() {
  var allSelected = false;
  var maxObjects;
  var searchRunId;
  var bulkButtons = new Array();
  var allObjectsMode = false;

  var rewriteBulkForm = function() {
    var checked = $("#result_table").find(":checked");
    if(allObjectsMode && checked.length==$("#result_table").find(":checkbox:not(#chk_sel_all)").length) {
      $("#div_bulk_content").html("<input type='hidden' name='sr_id' value='"+searchRunId+"' />");
      $("#bulk_message").html("All "+maxObjects+" items selected.")
    } else {
      allObjectsMode = false;
      var checkedIds = new Array();
      $("#div_bulk_content").html("");
      checked.each(function(index, item) {
        checkedIds.push($(item).attr('pk'));
      });
      for(var x=0;x<checkedIds.length;x++) {
        $("#div_bulk_content").append("<input type='hidden' name='pk["+x+"]' value='"+checkedIds[x]+"' />"); 
      }
      for(var x=0;x<bulkButtons.length;x++) {
        if(checkedIds.length) {
          bulkButtons[x].show();
        } else {
          bulkButtons[x].hide();
        }
      }
      if($("#result_table").find(":checkbox:not(#chk_sel_all)").length==checkedIds.length) {
        $("#bulk_message").html("All "+checkedIds.length ? checkedIds.length+" items on this page selected. To select all "+maxObjects+" items click <a href='#' class='sel_full'>here</a>." : "&nbsp;");
      } else {
        $("#bulk_message").html("&nbsp;");
      }
    }
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
      rewriteBulkForm();
    });
  }

  var initSearchCriterions = function() {
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
      }
      if(dt=="integer" || dt=="decimal" || dt=="fixnum") {
        h += "<option value='eq'>Equals</option>";
        h += "<option value='nq'>Not Equal To</option>";
        h += "<option value='gt'>Greater Than</option>";
        h += "<option value='lt'>Less Than</option>";
        h += "<option value='sw'>Starts With</option>";
        h += "<option value='ew'>Ends With</option>";
        h += "<option value='co'>Contains</option>";
      }
      if(dt=="string" || dt=="text") {
        h += "<option value='eq'>Equals</option>";
        h += "<option value='nq'>Not Equal To</option>";
        h += "<option value='sw'>Starts With</option>";
        h += "<option value='ew'>Ends With</option>";
        h += "<option value='co'>Contains</option>";
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
      'null':function(f) {f.hide();},
      'notnull':function(f) {f.hide()}
    }
    var bindValueValidations = function(tr) {
      var op = tr.find(".srch_crit_oper");
      var vField = tr.find(".srch_crit_value");
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
    
  return {
    init: function(max_objects,search_run_id) {
      maxObjects = max_objects;
      searchRunId = search_run_id;
      $("#frm_bulk").attr('action','');
      initBulkSelectors();
      initSelectFullList();
      initSearchCriterions();
    },
    addBulkHandler: function(button_name,form_path) {
      var b = $("#"+button_name);
      bulkButtons.push(b);
      b.click(function() {$("#frm_bulk").attr('action',form_path).submit();});
      rewriteBulkForm();
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
}
function newSchedule() {
  var rv = new Object();
  rv.key = "";
  rv.email = "";
  rv.hour = "0";
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
function writeScheduleContainer(container,rv) {
  if((rv.mon || rv.tue || rv.wed || rv.thu || rv.fri || rv.sat || rv.sun) && 
      rv.email || rv.ftpsvr) {
    var id = new Date().getTime();
    var ssa = "search_setup[search_schedules_attributes]["+id+"]";
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
    var ftp_lbl = (rv.ftpsvr && rv.ftpsvr.length > 0) ? "FTP: "+rv.ftpsvr : "";
    r += " at "+rv.hour+":00 to "+rv.email+" "+ftp_lbl+" - <a href='#' class='sched_edit'>Edit</a> | <a href='#' class='sched_remove'>Remove</a>";
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
}
function submitForm() {
  var coluids = []
  $("#used_columns option").each(function () {
    coluids.push($(this).attr("value"));
  });
  var f = $("#frm_current_search");
  var i;
  for(i=0;i<coluids.length;i++) {
    var h = "<input type='hidden' name='search_setup[search_columns_attributes]["+i+"][rank]' value='"+i+"' />";
    h = h + "<input type='hidden' name='search_setup[search_columns_attributes]["+i+"][model_field_uid]' value='"+coluids[i]+"' />";
    f.append(h);
  }
  var srt_uids = []
  $("#used_sorts option").each(function() {
    srt_uids.push([$(this).attr("value"),$(this).attr("ord")]);
  });
  for(i=0;i<srt_uids.length;i++) {
    var h = "<input type='hidden' name='search_setup[sort_criterions_attributes]["+i+"][rank]' value='"+i+"' />";
    h = h + "<input type='hidden' name='search_setup[sort_criterions_attributes]["+i+"][model_field_uid]' value='"+srt_uids[i][0]+"' />";
    h = h + "<input type='hidden' name='search_setup[sort_criterions_attributes]["+i+"][descending]' value='"+(srt_uids[i][1]=="a" ? "false" : "true")+"' />";
    f.append(h);
  }
  f.submit();
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
function make_columns(amf,available_obj,used_obj,list_type,list) {
  var used_columns = [];
  var unused_columns = amf.slice(0);
  var scs;
  if(list_type=='search_columns') {
    scs = list.search_setup.search_columns;
  } else {
    scs = list.search_setup.sort_criterions;
  }
  scs.sort(function(a,b) {
    var i = a.rank-b.rank;
    if(i!=0) { return i;}
    if(a.model_field_uid<b.model_field_uid) {
      return -1;
    } else {
      return 1;
    }
  });
  for(i=0;i<scs.length;i++) {
    var uid = scs[i].model_field_uid;
    var new_unused = []
    if(uid=="_blank") {
      var blank_obj = new Object;
      blank_obj.uid = "_blank";
      blank_obj.label = "[Blank]";
      used_columns.push(blank_obj);
    } else {
      for(j=0;j<unused_columns.length;j++) {
        if(unused_columns[j].uid==uid) {
          if(list_type=='sort_criterions') {
            unused_columns[j].descending = scs[i].descending
          }
          used_columns.push(unused_columns[j]);
        } else {
          new_unused.push(unused_columns[j]);
        }
      }
      unused_columns = new_unused;
    }
  }
  h = "";
  for(i=0;i<unused_columns.length;i++) {
    h = h + "<option value='"+unused_columns[i].uid+"'>"+unused_columns[i].label+"</option>";
  }
  available_obj.html(h);
  h = "";
  for(i=0;i<used_columns.length;i++) {
    var label = used_columns[i].label
    var ord = '';
    if(list_type=='sort_criterions') {
      label = label + (used_columns[i].descending ? " [Z > A]" : " [A > Z]");
      ord = "ord='"+(used_columns[i].descending ? "d" : "a")+"'"
    }
    h = h + "<option value='"+used_columns[i].uid+"' "+ord+">"+label+"</option>";
  }
  used_obj.html(h);
}
