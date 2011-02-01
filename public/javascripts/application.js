// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
$( function() {
    $("#lnk_hide_notice").click(function(ev) {
      ev.preventDefault();
      $('#notice').fadeOut();
    });
    $(".btn_cancel_mod").click( function() {
        $.modal.close();
    });
    $(".isdate").datepicker({dateFormat: 'yy-mm-dd'});
    
    //Make the shared/search_box partial work
    $("#srch_fields").change( function() {
        setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));
    });
    $("#srch_cond").change( function() {
        toggleSearchValue();
    });

    //Make the import buttons from the shared/mod_import partial work
    $("#mod_import").dialog({autoOpen:false,title:"Upload File",
      buttons:{"Upload":function() {
        $("#mod_import").dialog('close');
        $("#frm_imp_file").submit();
      }}
    });
    $( "#btn_import_file" )
    .click( function() {
        $("#mod_import").dialog('open');
    });

    //Make the export buttons from the shared/mod_export partial work
    $("#mod_export").dialog({autoOpen:false,title:"Download File",
      buttons:{"Download":function() {
        $("#mod_export").dialog('close');
        $("#frm_exp_file").submit();
      }}
    });
    $("#btn_export_file")
    .click( function() {
        $("#mod_export").dialog('open');
    });
    $("#lnk_feedback").click(function() {feedbackDialog();});
    $("button").button();
    
    $(".classification_expand").click(function(ev) {
      ev.preventDefault();
      $(this).hide();
      $(this).next("a.classification_shrink").show();
      $(this).nextAll("div.classification_detail_box").show("blind", { direction: "vertical" }, 500);
    })
    $(".classification_shrink").click(function(ev) {
      ev.preventDefault();
      $(this).hide();
      $(this).prev("a.classification_expand").show();
      $(this).nextAll("div.classification_detail_box").hide("blind", {direction: "vertical"}, 500);
    });
    $(".hts_field").change(function() {
      if(validateHTS($(this).val())) {
        $(this).removeClass("bad_data");
      } else {
        $(this).addClass("bad_data");
      }
    });
});
$(document).ready( function() {
    handleCustomFieldCheckboxes();
    $(':checkbox').css('border-style','none');
    $('#notice').fadeIn();
    $('.focus_first').focus();

    //make the shared/search_box partial work
    setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));

});
function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
}
function feedbackDialog() {
  content = "<div id='mod_feedback' style='display:none;'><textarea rows='10' id='ta_feedback_msg' name='message' /><br /><input type='checkbox' id='chk_fdbk_rsp' /> I would like a response to this message.</div>";
  send_data = {
    message: $("#ta_feedback_msg").val(),
    respond: (($('#chk_fdbk_rsp:checked').val() == undefined) ? "No" : "Yes"),
    location: window.location.href
  };
  send_data.source_page = $("form").serializeArray();
  $("body").append(content);
  $("#mod_feedback").dialog({title: "Send Feedback",
    buttons:{
      "Submit":function(){
        $.post('/feedback', send_data);
        $(this).dialog('close');   
        $("body").append("<div id='mod_thanks'>Thank you for your feedback.</div>");
        $("#mod_thanks").dialog({title: "Thank You",
          buttons:{"Close":function() {$(this).dialog('close');}}}); 
      },
      "Cancel":function() {
        $(this).dialog('close');
      } 
    }
    });
}

function toggleSearchValue() {
    var sv = $("#srch_val");
    var sc = $("#srch_cond");
    if($.inArray(sc.val(),['is_null','is_not_null','is_true','is_false'])==-1) {
        sv.removeAttr('disabled').show();
    } else {
        sv.attr('disabled', 'disabled').hide();
    }
}

function setSearchFields(field_select,val_text,con_select) {
    if (field_select.length > 0) {
        var date_or_bool = 'n'
        if(endsWith(field_select.val(),'date')) {
            date_or_bool = 'd'
        } else if (endsWith(field_select.val(),'bool')) {
            date_or_bool = 'b'
        }
        setSearchDatePicker(val_text,(date_or_bool == 'd'));
        setConditionDropdown(val_text,con_select,date_or_bool);
        toggleSearchValue();
    }
}

function setConditionDropdown(val_text,con_select,date_or_bool) {
    con_select.empty();
    if(date_or_bool == 'd') {
        appendSelect(con_select,'eq','equals');
        appendSelect(con_select,'gt','is greater than');
        appendSelect(con_select,'lt','is less than');
        appendSelect(con_select,'is_null','is empty');
        appendSelect(con_select,'is_not_null','is not empty');
    } else if(date_or_bool == 'b') {
        appendSelect(con_select,'is_true','Yes');
        appendSelect(con_select,'is_false','No');
    } else {
        appendSelect(con_select,'eq','equals');
        appendSelect(con_select,'contains','contains');
        appendSelect(con_select,'sw','starts with');
        appendSelect(con_select,'ew','ends with');
        appendSelect(con_select,'is_null','is empty');
        appendSelect(con_select,'is_not_null','is not empty');
    }
}

function appendSelect(s,v,t) {
    s.append($("<option></option>").attr("value",v).text(t));
}

function setSearchDatePicker(val_text,isDate) {
    if(isDate) {
        val_text.datepicker({dateFormat: 'yy-mm-dd'});
    } else {
        val_text.datepicker("destroy");
    }
}

function toggleMessageRead(id, onCallback) {
    $.get('/messages/'+id+'/read', function(data) {
        onCallback(id);
        readCount = data;
        $("#message_count").html((readCount!='0') ? "(<a href='/messages'>"+readCount+"</a>)" : "");
    });
}

function addHiddenFormField(parentForm,name,value,id,style_class) {
    $("<input type='hidden' name='"+name+"' value='"+value+"' id='"+id+"' class='"+style_class+"' />")
    .appendTo(parentForm);
}
function loading(wrapper) {
  wrapper.html("<img src='/images/ajax-loader.gif' alt='loading'/>");
}

//address setup
function setupShippingAddress(companyType,select,display,companyId,selected_val) {
   select.live("change",function(){
     getAddress(display,select.val());
   });
   getShippingAddressList(select,companyId,selected_val,companyType);
}
function getShippingAddressList(select,companyId,selected_val,companyType) {
  if(isNaN(companyId)) {
     select.html('').append($("<option></option>").
            attr("value",'').
            text("Select a "+companyType));
  } else {
    $.getJSON('/companies/'+companyId+'/shipping_address_list.json', function(data) {
        t_val = ''
        if(data.length==0) {
          t_val = 'No addresses exist for this company'
        } else {
          t_val = 'Select an address' 
        }
        select.html('').append($("<option></option>").
            attr("value",'').
            text(t_val));
        for (i=0; i<data.length; i++) {
            select.
            append($("<option></option>").
            attr("value",data[i].address.id).
            text(data[i].address.name)).change(); 
        }
        select.val(selected_val).change();
      });
    }
}
/* OPTIONS: 
    includeName: true 
*/
function getAddress(wrapper,address_id,options) {
  defaultOptions = {
    includeName: true,
  }
  
  if (typeof options == 'object') {
    options = $.extend(defaultOptions, options);
  } else {
    options = defaultOptions;
  }
  if(address_id > 0) {
    loading(wrapper);
    $.getJSON('/addresses/'+address_id+'/render_partial.json', function(data) {
      h = ''
      if(options.includeName) { h = h+'<b>'+data.address.name+'</b></br>'; }
      h = h + makeLine(data.address.line_1,true) + makeLine(data.address.line_2,true);
      if(data.address.city!=null && data.address.city.length>0) {
        h = h + data.address.city+',';
      }
      h = h + makeLine(data.address.state,false) + ' ' + makeLine(data.address.postal_code,false)
          + '</br>' + makeLine(data.address.country.name,false);
      wrapper.html(h);
    });
  }
  else {
    wrapper.html('');
  }
}

function makeLine(base,include_break) {
  if(!(base==null || base.length==0)) {
    return base + (include_break ? '<br />' : '');
  }
  else {
    return '';
  }
}
function destroy_nested(prefix, link) {
  link.prev('.'+prefix+'_destroy').attr('value','true');
  link.parents('.'+prefix+'_row').fadeOut();
}
function handleCustomFieldCheckboxes() {
  $(".cv_chkbx").each(function() {
    $(this).change(function() {
      $("#hdn_"+$(this).attr("id").substring(4)).val($(this).is(':checked') ? "true" : "false");
    });
  });
}
/* right now just validating length */
function validateHTS(inputStr) {
  base = stripNonNumeric(inputStr);
  return base.length>5  
}
function stripNonNumeric(inputStr) {
    return inputStr.replace(/[^0-9]/g, ''); 
}

