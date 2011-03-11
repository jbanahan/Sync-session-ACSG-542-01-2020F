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
  rv.email = "";
  rv.hour = "0";
  rv.mon = false;
  rv.tue = false;
  rv.wed = false;
  rv.thu = false;
  rv.fri = false;
  rv.sat = false;
  rv.sun = false;
  rv.id = "";
  return rv;
}
function findScheduleContainerById(id) {
  return $('.sch_id[value="'+id+'"]').parents('.sch_data_cont');
}
function removeSchedule(container) {
  container.children(".sch_destroy").val("true");
  container.hide();
}
function readScheduleContainer(c) {
  var rv = new Object();
  rv.email = c.children(".sch_email").val();
  rv.hour = c.children(".sch_hr").val();
  rv.mon = getDay(c,"mon");
  rv.tue = getDay(c,"tue");
  rv.wed = getDay(c,"wed");
  rv.thu = getDay(c,"thu");
  rv.fri = getDay(c,"fri");
  rv.sat = getDay(c,"sat");
  rv.sun = getDay(c,"sun");
  rv.id = c.children(".sch_id").val();
  return rv;
}
function writeScheduleContainer(container,rv) {
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
  r += " at "+rv.hour+":00 to "+rv.email+" - <a href='#' class='sched_edit'>Edit</a> | <a href='#' class='sched_remove'>Remove</a>";
  r += "<input class='sch_mon' name='"+ssa+"[run_monday]' type='hidden' value='"+rv.mon+"'/>";
  r += "<input class='sch_tue' name='"+ssa+"[run_tuesday]' type='hidden' value='"+rv.tue+"'/>";
  r += "<input class='sch_wed' name='"+ssa+"[run_wednesday]' type='hidden' value='"+rv.wed+"'/>";
  r += "<input class='sch_thu' name='"+ssa+"[run_thursday]' type='hidden' value='"+rv.thu+"'/>";
  r += "<input class='sch_fri' name='"+ssa+"[run_friday]' type='hidden' value='"+rv.fri+"'/>";
  r += "<input class='sch_sat' name='"+ssa+"[run_saturday]' type='hidden' value='"+rv.sat+"'/>";
  r += "<input class='sch_sun' name='"+ssa+"[run_sunday]' type='hidden' value='"+rv.sun+"'/>";
  r += "<input class='sch_hr' name='"+ssa+"[run_hour]' type='hidden' value='"+rv.hour+"'/>";
  r += "<input class='sch_email' name='"+ssa+"[email_addresses]' type='hidden' value='"+rv.email+"'/>";
  r += "<input class='sch_destroy' name='"+ssa+"[_destroy]' type='hidden' value='' />";
  r += "</li>";
  container.append(r); 
  applyScheduleHooks();
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
  rv.id = $("#sd_id").val();
  return rv; 
}
function writeScheduleInterface(s) {
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
    srt_uids.push([$(this).attr("value"),$(this).attr("ord")])
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
