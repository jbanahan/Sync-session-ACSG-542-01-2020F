var OpenChainMilestonePlan = (function() {
  
  var addRow = function(previousRow,json_data) {
    var my_index = new Date().getTime();
    var h = "<tr id='milestone_row_"+my_index+"' style='display:none;' class='definition_row' row_index='"+my_index+"'>";
    h += "<td><a href='#' class='add_row'><img src='/images/green_plus_24.png' alt='Add Row' title='Add Row' /></a>&nbsp;<a href='#' class='remove_row'><img src='/images/gray_minus_24.png' alt='Remove Row' title='Remove Row'/></a>&nbsp;<a href='#' class='edit_row'><img src='/images/blue_edit_24.png' title='Edit' alt='Edit'/></a><input type='hidden' name='[milestone_definition_rows]["+my_index+"][display_rank]' value='"+json_data.display_rank+"'/></td>";
    h += "<td><input type='hidden' class='hdn_mfuid' name='[milestone_definition_rows]["+my_index+"][model_field_uid]' value='"+json_data.model_field_uid+"'/><span class='mfuid_lbl'/></td>";
    h += "<td><input type='text' name='[milestone_definition_rows]["+my_index+"][days_after_previous]' value='"+json_data.days_after_previous+"' readonly='readonly' style='border:none;width:2em;color:black;'/></td>";
    h += "<td><input type='hidden' class='hdn_mfuid' name='[milestone_definition_rows]["+my_index+"][previous_model_field_uid]' value='"+json_data.previous_milestone_model_field_uid+"'/><span class='mfuid_lbl' /></td>";
    h += "<td><input type='checkbox' disabled='disabled' name='[milestone_definition_rows]["+my_index+"][final_milestone]' value='1' "+(json_data.final_milestone ? "checked='checked'" : "")+"/></td></tr>";
    previousRow.after(h);
    var myRow = previousRow.next();
    myRow.find('.hdn_mfuid').each(function() {$(this).next(".mfuid_lbl").html(fieldLabel($(this).val()));});
    myRow.fadeIn('slow');
    setDisplayRanks();
    return myRow;
  }
  var removeRow = function(link,skipConfirm) {
    if (skipConfirm || window.confirm("Removing this row will also remove any rows that are based on it?  Are you sure you want to continue?")) {
      var row = link.parents('.definition_row');
      var mf_uid = getRowModelFieldUid(row);
      if(mf_uid) {
        $("#definitions_table").find(':input[name*="[previous_model_field_uid]"]').each(function() {
          var pVal = $(this).val();
          if(pVal==mf_uid) {
            removeRow($($(this).parents('.definition_row').find('.remove_row')),true);
          }
        });
      }
      link.after("<input type='hidden' name='[milestone_definition_rows]["+row.attr('row_index')+"][destroy]' value='true'/>");
      row.fadeOut('slow');
    }
  }
  var getRowModelFieldUid = function(row) {
    return row.find(':input[name*="[model_field_uid]"]').val();
  }
  var setDisplayRanks = function() {
    var rank = 0;
    $("#definitions_table").find('input[name*="[display_rank]"]').each(function() {
      $(this).val(rank);
      rank++;
    });
  }
  var baseFieldOptions;
  

  var fieldLabel = function(modelFieldUid) {
    for(var i in baseFieldOptions) {
      var wrapperArray = baseFieldOptions[i];
      for(var j=0; j<wrapperArray.length;j++) {
        if(wrapperArray[j][1]==modelFieldUid) {
          return wrapperArray[j][0];
        }
      }
    }
    return null;
  }
  var setMFUIDLabel = function(fld) {
    fld.next('.mfuid_lbl').html(fieldLabel(fld.val()));
  }
  var showNewPlanPrompt = function() {
    if(!$("#starting_def_uid").val()) {
      $("#mod_new_prompt").dialog({title:"Select Starting Field",width:"400",
          buttons:{"OK":function() {
            $("#starting_def_uid").val($("#sel_first_milestone").val());
            $("#starting_def_uid").change();
            $("#mod_new_prompt").dialog('close');
          },"Cancel":function() {
            window.location = '/milestone_plans';
          }},modal:true, closeOnEscape: false,
             open: function(event, ui) { $(".ui-dialog-titlebar-close").hide(); },
             close: function(evt, ui) {$(".ui-dialog-titlebar-close").show();}});
    }
  }
  var buildFieldOptions = function(currentlySelectedMfuid) {
    var usedMfuids = [];
    $(':input[name*="[model_field_uid]"]').each(function() {
      var mfuidVal = $(this).val();
      if(mfuidVal!=currentlySelectedMfuid) {
        usedMfuids.push(mfuidVal);
      }
    });
    var h = "<option value=''>Select A Field</option>";
    for(var grp in baseFieldOptions) {
      h += "<optgroup label='"+grp+"'>";
      var wrapperArray = baseFieldOptions[grp];
      for(var i=0; i<wrapperArray.length;i++) {
        if($.inArray(wrapperArray[i][1],usedMfuids)==-1) {
          h += "<option value='"+wrapperArray[i][1]+"' "+(wrapperArray[i][1]==currentlySelectedMfuid ? "selected" : "")+" >"+wrapperArray[i][0]+"</option>";
        }
      }
      h += "</optgroup>"
    }
    return h;
  }
  var editRow = function(row,isNew) {
    var myMfuid = getRowModelFieldUid(row);
    var basedOnMfuid = row.find(':input[name*="[previous_model_field_uid]"]').val();
    var h = "<input type='hidden' id='edit_scrap_row' value='"+(isNew ? "true" : "false")+"'/><input type='hidden' id='edit_row_id' value='"+row.attr('id')+"'/><table>";
    h += "<tr><td class='label_cell'>Field:</td><td><select id='edit_fld'>"+buildFieldOptions(myMfuid)+"</select></td></tr>";
    h += "<tr><td class='label_cell'>Days After Last Milestone:</td><td><input type='text' class='integer' size='5' id='edit_days' value='"+row.find(':input[name*="[days_after_previous]"]').val()+"' /></td></tr>";
    h += "<tr><td class='label_cell'>Based On:</td><td><input type='hidden' id='edit_based_on' value='"+basedOnMfuid+"'/>"+fieldLabel(basedOnMfuid)+"</td></tr>";
    h += "<tr><td class='label_cell'>SLA Complete <a href='#' class='sla_help'>?</a>:</td><td><input type='checkbox' id='edit_sla_complete' value='true'/></td></tr>";
    h += "</table>";
    $("#edit_row_inner").html(h);
    $("#edit_days").jStepper({allowDecimals:false});
    $("#mod_edit_row").dialog('open');
  }

  return {
    addEmptyRow: function(previousRow) {
      var mfuid = getRowModelFieldUid(previousRow);
      var data = {model_field_uid:"",days_after_previous:0,previous_milestone_model_field_uid:mfuid,final_milestone:false};
      editRow(addRow(previousRow,data),true,mfuid);
    },
    init: function(milestonePlanId,possibleFields) {
      baseFieldOptions = possibleFields;
      $("#mod_edit_row").dialog({autoOpen:false,modal:true,width:400,title:"Milestone Row",buttons:{
        "OK":function() {
          if(!$("#edit_fld").val()) {
            $("#edit_errors").html("Please select a field to track.");
          } else if(!$("#edit_days").val()) {
            $("#edit_errors").html("Please set the number of days that this milestone takes.");
          }else {
            var row = $('#'+$("#edit_row_id").val());
            row.find(':input[name*="[model_field_uid]"]').val($("#edit_fld").val());
            row.find(':input[name*="[days_after_previous]"]').val($("#edit_days").val());
            row.find(':input[name*="[previous_model_field_uid]"]').val($("#edit_based_on").val());
            if($("#edit_sla_complete:checked").length) {
              $(':input[name*="[final_milestone]"]').removeAttr('checked'); //only one final milestone
              row.find(':input[name*="[final_milestone]"]').attr('checked','checked');
            } else {
              row.find(':input[name*="[final_milestone]"]').removeAttr('checked');
            }
            row.find(":input").change();
            $("#edit_scrap_row").val("false");
            $("#mod_edit_row").dialog('close');
          }
        },
        "Cancel":function() {
          $("#mod_edit_row").dialog('close');
        }},
        close:function() {
          if($("#edit_scrap_row").val()=="true") {
            $("#"+$("#edit_row_id").val()).remove();  
          }
        }    
      });
      $("#mod_sla_help").dialog({autoOpen:false,width:400,title:"Help - SLA Complete",buttons:{"Close":function() {$("#mod_sla_help").dialog('close');}}});
      $(".sla_help").live('click',function(evt) {
        evt.preventDefault();
        $("#mod_sla_help").dialog('open');
      });
      $(".hdn_mfuid").each(function() {setMFUIDLabel($(this));});
      $(".hdn_mfuid").live('change',function(evt) {
        setMFUIDLabel($(this));
      });
      $(".add_row").live('click',function(evt) {
        evt.preventDefault();
        OpenChainMilestonePlan.addEmptyRow($(this).parents(".definition_row"));
      });
      $(".remove_row").live('click',function(evt) {
        evt.preventDefault();
        removeRow($(this),false);    
      });
      $(".edit_row").live('click',function(evt) {
        evt.preventDefault();
        editRow($(this).parents('.definition_row'),false);
      });
      if(milestonePlanId) { 
        $.get('/milestone_plans/'+milestonePlanId+'/milestone_definitions.json',function(definitions) {
          var lastRow = $("#first_milestone_row"); 
          for(var i=0; i<definitions.length; i++) {
            if(definitions[i].milestone_definition.previous_milestone_model_field_uid) { //don't re-add base milestone}
              lastRow = addRow(lastRow,definitions[i].milestone_definition);
            }
          }
          setDisplayRanks();
          }
        );
      }
      $("#frm_mp").submit(function(evt) {
        if(!$("#mp_name").val()) {
          window.alert("Please set the plan name.");
          evt.preventDefault();
        }
      });
      showNewPlanPrompt();
    }
  };
})();
