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
    //.isdate must be before the tooltip call
    $(".isdate").datepicker({dateFormat: 'yy-mm-dd'});
    $(".fieldtip").tooltip({
      // place tooltip on the right edge
      position: "center right",
      // a little tweaking of the position
      offset: [-2, 10],
      // use the built-in fadeIn/fadeOut effect
      effect: "fade",
      // custom opacity setting
      opacity: 0.9         
    });
    $(".dialogtip").tooltip({
      position: "center left",
      effect: "fade",
      opacity: 0.9,
      onBeforeShow: function(event, position){
        this.getTip().css({'z-index':'9999'});
       }
    });
    $(".tiplink").tooltip({position:"bottom center", effect: "fade", opacity: 0.9, offset: [8,0]});
    
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
    $("#lnk_feedback").click(function(ev) {
        ev.preventDefault();
        feedbackDialog();
    });
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
    $(".comment_sub").button();
    $(".comment_lnk").click(function(ev) {
      ev.preventDefault();
      var bodyRow = $(this).parents(".comment_header").next();
      if(bodyRow.is(':visible')) {
        bodyRow.hide();
      } else {
        bodyRow.show();
      }
    });
    $(".comment_exp_all").click(function(ev) {
      ev.preventDefault();
      $(".comment_body").show();
      $(this).siblings(".comment_cls_all").show();
      $(this).hide();
    });
    $(".comment_cls_all").click(function(ev) {
      ev.preventDefault();
      $(".comment_body").hide();
      $(this).siblings(".comment_exp_all").show();
      $(this).hide();
    });
    $(".comment_edit_link").click(function(ev) {
      ev.preventDefault();
      var myRow = $(this).parents(".comment_body");
      myRow.hide();
      myRow.prev().hide();
      myRow.next().show();
    });
    attachmentButton();

    $("#edit_line_product").change(function() {
      if($(this).val().length>0) {
        $("#edit_line_uom").html("<span style='font-size:80%;'>...loading...</span>");
        getProductUOM($(this).val(),function(uom) {
          $("#edit_line_uom").html(uom);
        });
      }
    });
    $(".lnk_tariff_popup").live("click", function(evt) {
      evt.preventDefault();
      var hts = $(this).attr('hts');
      var c_id = $(this).attr('country');
      tariffPopUp(hts,c_id);
    });
});
$(document).ready( function() {
    handleCustomFieldCheckboxes();
    $(':checkbox').css('border-style','none');
    $('#notice').fadeIn();
    $('.focus_first').focus();

    //make the shared/search_box partial work
    setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));

    //Hide subscriptions buttons until feature is better implemented (ticket 87)
    $("#btn_subscriptions").hide();
    
    //when closing a dialog, make sure to take focus from all inputs
    $("div.ui-dialog").live( "dialogbeforeclose", function(event, ui) {
      $(this).find(":input").blur();
    });
});
function attachmentButton() {
  $(".attach_button").button();
  $(".attach_button").each(function() {
    var fileInput = $("body").find(":file");
    var aButton = $(this);
    if(fileInput.length!=1) {
      //either many file objects or none, either way we can't automate behavior
      return;
    }
    if(fileInput.val().length==0) {
      $(this).hide();
    }
    fileInput.change(function() {
      if(fileInput.val().length==0) {
        aButton.fadeOut('slow');
      } else {
        aButton.fadeIn('slow');
      }
    });
  });
}
function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
}
function feedbackDialog() {
  content = "<div id='mod_feedback' style='display:none;'><textarea rows='10' id='ta_feedback_msg' name='message' /><br /><input type='checkbox' id='chk_fdbk_rsp' /> I would like a response to this message.</div>";
  var source_form_data = "";
  $("body").append(content);
  $("#mod_feedback").dialog({title: "Send Feedback",
    buttons:{
      "Submit":function(){
        send_data = {
          message: $("#ta_feedback_msg").val(),
          respond: (($('#chk_fdbk_rsp:checked').val() == undefined) ? "No" : "Yes"),
          location: window.location.href
        };
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
          + '</br>' + makeLine(data.address.country==null ? "" : data.address.country.name,false);
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
/* Get all open orders available to user and pass to callback function */
function getOpenOrders(callback) {
  $.getJSON("/orders/all_open.json",callback);
}
function getOpenSalesOrders(callback) {
  $.getJSON("/sales_orders/all_open.json",callback);
}
/* Get an order with lines & associated products and pass to callback function */
function getOrder(id, callback) {
  $.getJSON("/orders/"+id+".json",callback);
}
function getSalesOrder(id, callback) {
  $.getJSON("/sales_orders/"+id+".json",callback);
}
/* Get's the product's UOM via Ajax and passes it to the callback function */
function getProductUOM(id, callback) {
  getProductJSON(id, function(data) {
      if(data.product!=undefined) {
        callback(data.product.unit_of_measure);
      }
  });
}
/* Get's the product's JSON reprsentation and passes it to the callback function */
function getProductJSON(id, callback) {
  $.getJSON("/products/"+id+".json",callback);
} 
/* right now just validating length */
function validateHTS(inputStr) {
  base = stripNonNumeric(inputStr);
  return base.length>5  
}
function stripNonNumeric(inputStr) {
    return inputStr.replace(/[^0-9]/g, ''); 
}
/*helpers for shipment / delivery screens*/
function setupPackScreen(isSalesOrder,openEdit,cancelPath) {

  $("#mod_edit_line").dialog({autoOpen:false,title:'Edit Line',
    width:'auto',
    buttons:{"Save":function() {$("#frm_edit_line").submit();},
             "Cancel":function() {window.location = cancelPath;}}  
  });
  $("#btn_add_line").button().click(function() {
    $("#mod_edit_line").dialog('open');
  });
  $(".lnk_detail").click(function(ev) {
    ev.preventDefault();
    $(this).parents("tr.shp_line").next().toggle();
  });
  $("#lnk_all_details").click(function(ev) {
    ev.preventDefault();
    if(all_details_open) {
      $(".shp_line_detail").hide();
    } else {
      $(".shp_line_detail").show();
    }
    all_details_open = !all_details_open;
  });

  if(openEdit) {$("#mod_edit_line").dialog('open');}
  var titleNoun = isSalesOrder ? "Sale" : "Order"
  $("#mod_pack_order").dialog({autoOpen:false,title:'Pack '+titleNoun,width:'auto',
    buttons:{"Add":function() {$("#frm_pack_order").submit();},
    "Cancel":function() {$("#mod_pack_order").dialog('close');}}
  });
  $("#mod_open_orders").dialog({autoOpen:false,title:'Select '+titleNoun,width:'auto',
      buttons:{"OK":function() {
        var id = $("#sel_open_orders").val();
        if(id) {
          $("#mod_open_orders").dialog('close');
          if(isSalesOrder) {
            openPackSalesOrder(id);
          } else {
            openPackOrder(id);
          }
        } else {
          window.alert(isSalesOrder ? "Select a sale first." : "Select an order first.");
        }
      },
      "Cancel":function() {$("#mod_open_orders").dialog('close');}}});
  $("#btn_add_order").click(function() {
    $("#mod_open_orders").dialog('open');
    var openFunction = function(data) {
      var i;
      if(data.length==0) {
        $("#sel_open_orders").html("<option>No "+titleNoun+"s Available</option>");
      } else {
        var opt = "";
        for(i=0;i<data.length;i++) {
          var o = isSalesOrder ? data[i].sales_order : data[i].order;
          opt += "<option value='"+o.id+"'>"+o.order_number+"</option>";
        }
        $("#sel_open_orders").html(opt);
      }
    }
    if(isSalesOrder) {
      getOpenSalesOrders(openFunction);
      } else {
      getOpenOrders(openFunction);
    }
  });
}
function openPackSalesOrder(id) {
  $("#div_pack_order_content").html("Loading...");
  $("#mod_pack_order").dialog('open');
  getSalesOrder(id,function(data) {
    var h = "";
    var order = data.sales_order
    h += "<div>Pack Sale: "+order.order_number+"</div><table class='detail_table'><thead><tr><th>Sale Row</th><th>Product</th><th>Sold</th><th>Delivered</th></tr></thead><tbody>";
    var i;
    for(i=0;i<order.sales_order_lines.length;i++) {
      var line = order.sales_order_lines[i];
      h+="<tr><td><input type='hidden' name='[lines]["+i+"][linked_sales_order_line_id]' value='"+line.id+"'/>"+line.line_number+"</td><td>"+line.product.name+"<input type='hidden' name='[lines]["+i+"][product_id]' value='"+line.product.id+"'/></td><td>"+line.quantity+"</td><td><input type='text' name='[lines]["+i+"][quantity]'/></td></tr>";
    }
    h += "</tbody></table>";
    $("#div_pack_order_content").html(h);
  });
}
function openPackOrder(id) {
  $("#div_pack_order_content").html("Loading...");
  $("#mod_pack_order").dialog('open');
  getOrder(id,function(data) {
    var h = "";
    var order = data.order
    h += "<div>Pack Order: "+order.order_number+"</div><table class='detail_table'><thead><tr><th>Order Row</th><th>Product</th><th>Ordered</th><th>Shipped</th></tr></thead><tbody>";
    var i;
    for(i=0;i<order.order_lines.length;i++) {
      var line = order.order_lines[i];
      h+="<tr><td><input type='hidden' name='[lines]["+i+"][linked_order_line_id]' value='"+line.id+"'/>"+line.line_number+"</td><td>"+line.product.name+"<input type='hidden' name='[lines]["+i+"][product_id]' value='"+line.product.id+"'/></td><td>"+line.quantity+"</td><td><input type='text' name='[lines]["+i+"][quantity]' /></td></tr>";
    }
    h += "</tbody></table>";
    $("#div_pack_order_content").html(h);
  });
}
function tariffPopUp(htsNumber,country_id) {
  var mod = $("#mod_tariff_popup");
  if(mod.length==0) {
    $("body").append("<div id='mod_tariff_popup'><div id='tariff_popup_content'></div></div>");
    mod = $("#mod_tariff_popup");
    mod.dialog({autoOpen:false,title:'Tariff Information',width:'400',height:'500',
      buttons:{"Close":function() {$("#mod_tariff_popup").dialog('close');}}
    });
  }
  var c = $("#tariff_popup_content");
  c.html("Loading tariff information...");
  mod.dialog('open');
  $.ajax({
    url:'/official_tariffs/find?hts='+htsNumber+'&cid='+country_id,
    dataType:'json',
    error: function(req,msg,obj) {
      c.html("We're sorry, an error occurred while trying to load this information.");

    },
    success: function(data) {
      var h = '';
      if(data==null) {
        h = "No data was found for tariff "+htsNumber;
      } else {
        var o = data.official_tariff
        h = "<table class='tbl_hts_popup'><tbody>";
        h += htsDataRow("Country:",o.country.name);
        h += htsDataRow("Tariff #:",o.hts_code);
        h += htsDataRow("General Rate:",o.general_rate)
        h += htsDataRow("Chapter:",o.chapter);
        h += htsDataRow("Heading:",o.heading);
        h += htsDataRow("Sub-Heading:",o.sub_heading);
        h += htsDataRow("Text:",o.remaining_description);
        h += htsDataRow("Special Rates:",o.special_rates);
        h += htsDataRow("Add Valorem:",o.add_valorem_rate);
        h += htsDataRow("Per Unit:",o.per_unit_rate);
        h += htsDataRow("UOM:",o.unit_of_measure);
        h += htsDataRow("MFN:",o.most_favored_nation_rate);
        h += htsDataRow("GPT:",o.general_preferential_tariff_rate);
        h += htsDataRow("Erga Omnes:",o.erga_omnes_rate);
        h += htsDataRow("Column 2:",o.column_2_rate);
        if(o.official_quota!=undefined) {
          h += htsDataRow("Quota Category",o.official_quota.category);
          h += htsDataRow("SME Factor",o.official_quota.square_meter_equivalent_factor);
          h += htsDataRow("SME UOM",o.official_quota.unit_of_measure);
        }
        h += "</tbody></table>";
      }
      c.html(h);
    }
  });
}

function htsDataRow(label,data) {
  if(data!=undefined && jQuery.trim(data).length>0) {
    return "<tr class='hover'><td class='lbl_hts_popup'>"+label+"</td><td>"+data+"</td></tr>";
  } else {
    return "";
  }
}

function loadUserList(destinationSelect,selectedId) {
  $.getJSON('/users.json',function(data) {
    var i;
    var h = "";
    for(i=0;i<data.length;i++) {
      var company = data[i].company;
      var j;
      for(j=0;j<company.users.length;j++) {
        var u = company.users[j];
        var selected = (u.id==selectedId ? "selected=\'true\' " : "");
        h += "<option value='"+u.id+"' "+selected+">"+company.name+" - "+u.first_name+" "+u.last_name+"</option>";
      }
    }
    destinationSelect.html(h);
  });
}
