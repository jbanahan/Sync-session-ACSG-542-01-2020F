// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
$( function() {
    $(".btn_cancel_mod").button().click( function() {
        $.modal.close();
    });
    $("#order_line_expected_ship_date").datepicker({dateFormat: 'yy-mm-dd'});
    $("#order_line_expected_delivery_date").datepicker({dateFormat: 'yy-mm-dd'});
    $("#order_line_ship_no_later_date").datepicker({dateFormat: 'yy-mm-dd'});

    //Make the shared/search_box partial work
    $("#srch_fields").change( function() {
        setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));
    });
    $("#srch_cond").change( function() {
        toggleSearchValue();
    });
    $("#srch_submit").button();
    $("#btn_srch_bkmrk").button();

    //Make the import buttons from the shared/mod_import partial work
    $("#mod_import").dialog({autoOpen:false,title:"Upload File",
      buttons:{"Upload":function() {
        $("#mod_import").dialog('close');
        $("#frm_imp_file").submit();
      }}
    });
    $( "#btn_import_file" )
    .button()
    .click( function() {
        $("#mod_import").dialog('open');
    });
    $("#imported_file_submit")
    .button();

    //Make the export buttons from the shared/mod_export partial work
    $("#mod_export").dialog({autoOpen:false,title:"Download File",
      buttons:{"Download":function() {
        $("#mod_export").dialog('close');
        $("#frm_exp_file").submit();
      }}
    });
    $("#btn_export_file")
    .button()
    .click( function() {
        $("#mod_export").dialog('open');
    });
});
$(document).ready( function() {
    $(':checkbox').css('border-style','none');
    $('#notice').fadeIn();

    //make the shared/search_box partial work
    setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));

});
function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
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

function setDatePickers(arrayOfFields) {
  for(i=0;i<arrayOfFields.length;i++) {
    arrayOfFields[i].datepicker({dateFormat: 'yy-mm-dd'});
  }
}

//address setup
function setupShippingAddress(select,display,companyId,selected_val) {
   select.live("change",function(){
     getAddress(display,select.val());
   });
   getShippingAddressList(select,companyId,selected_val);
}
function getShippingAddressList(select,companyId,selected_val) {
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
