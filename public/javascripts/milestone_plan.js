var OpenChainMilestonePlan = (function() {
  
  return {
    addRow: function(previousRow,json_data) {
      var my_index = new Date().getTime();
      var h = "<tr id='milestone_row_"+my_index+"'><td><input type='text' name='[milestone_definition_rows]["+my_index+"][model_field_uid]' value='"+json_data.model_field_uid+"'/></td>";
      h += "<td><input type='text' name='[milestone_definition_rows]["+my_index+"][days_after_previous]' value='"+json_data.days_after_previous+"'/></td>";
      h += "<td><input type='text' name='[milestone_definition_rows]["+my_index+"][previous_model_field_uid]' value='"+json_data.previous_milestone_model_field_uid+"'/></td>";
      h += "<td><input type='checkbox' name='[milestone_definition_rows]["+my_index+"][final_milestone]' value='1' "+(json_data.final_milestone ? "checked='checked'" : "")+"/></td></tr>";
      previousRow.after(h);
    }
  };
})();
