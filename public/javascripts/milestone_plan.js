var OpenChainMilestonePlan = (function() {
  
  var addRow = function(previousRow,json_data) {
    var my_index = new Date().getTime();
    var h = "<tr id='milestone_row_"+my_index+"' style='display:none;' class='definition_row' row_index='"+my_index+"'>";
    h += "<td><a href='#' class='add_row'>+</a>&nbsp;<a href='#' class='remove_row'>-</a><input type='hidden' name='[milestone_definition_rows]["+my_index+"][display_rank]' value='"+json_data.display_rank+"'/></td>";
    h += "<td><input type='hidden' class='hdn_mfuid' name='[milestone_definition_rows]["+my_index+"][model_field_uid]' value='"+json_data.model_field_uid+"'/><span class='mfuid_lbl'/></td>";
    h += "<td><input type='text' name='[milestone_definition_rows]["+my_index+"][days_after_previous]' value='"+json_data.days_after_previous+"'/></td>";
    h += "<td><input type='hidden' class='hdn_mfuid' name='[milestone_definition_rows]["+my_index+"][previous_model_field_uid]' value='"+json_data.previous_milestone_model_field_uid+"'/><span class='mfuid_lbl' /></td>";
    h += "<td><input type='checkbox' name='[milestone_definition_rows]["+my_index+"][final_milestone]' value='1' "+(json_data.final_milestone ? "checked='checked'" : "")+"/></td></tr>";
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
    fld.next('mfuid_lbl').html(fieldLabel(fld.val()));
  }

  return {
    addEmptyRow: function(previousRow) {
      data = {model_field_uid:"",days_after_previous:0,previous_milestone_model_field_uid:getRowModelFieldUid(previousRow),final_milestone:false};
      return addRow(previousRow,data);
    },
    init: function(milestonePlanId,possibleFields) {
      baseFieldOptions = possibleFields;
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
      $.get('/milestone_plans/'+milestonePlanId+'/milestone_definitions.json',function(definitions) {
        var lastRow = $("#first_milestone_row"); 
        for(var i=0; i<definitions.length; i++) {
          if(definitions[i].milestone_definition.previous_milestone_model_field_uid) { //don't re-add base milestone}
            lastRow = addRow(lastRow,definitions[i].milestone_definition);
          }
        }
        setDisplayRanks();
      });
    }
  };
})();
