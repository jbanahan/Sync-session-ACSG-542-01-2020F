var OpenChain = (function() {
  //private stuff
  var authToken;
  var mappedKeys = new Object();
  var keyMapPopUp = null;
  var invalidTariffFields = [];

  var initRemoteValidate = function() {
    $(".rvalidate").live('change',function() {
        remoteValidate($(this));
    });
    $("form").live('submit',function(ev) {
      remoteValidateFormBlock($(this),ev);
    });
  }
  var remoteValidateFormBlock = function(form,ev) {
    if(form.find("input.error").size()) {
      window.alert("Please correct errors and try again.");
      ev.preventDefault();
    }
  }
  var remoteValidate = function(field) {
    mf_id = field.attr('mf_id');
    if(!mf_id) {
      return;
    }
    field.nextAll(".val_status").remove();
    field.after("<img src='/images/ajax-loader.gif' class='val_status' title='Validating...' style='display:none;'/>");
    field.next().fadeIn();
    $.getJSON('/field_validator_rules/validate',{mf_id: mf_id, value: field.val()},function(data) {
      field.nextAll(".val_status").remove();
      if(data.length) {
        var m = "";
        $.each(data,function(i,v) {m += v+"<br />"});
        field.addClass("error");
        field.after("<img src='/images/error.png' alt='Field Error' class='val_status'/>");
        field.next().after("<div class='val_status tooltip'>"+m+"</div>");
        field.next().tooltip({onShow: function() {
          return OpenChain.raiseTooltip(this.getTip());
        }});
      } else {
        field.removeClass("error");
      }
    });
  }
  var keyDialogClose = function() {keyMapPopUp.dialog('close');}
  var unbindKeys = function() {
    $(document).unbind('keyup');
    $(document).bind('keyup','k',showKeyboardMapPopUp);
  }
  var showKeyboardMapPopUp = function() {
    $(document).unbind('keyup');
    var str = "Action Keys:<br />k: Undo Action Keys (close this window)<br />";
    for(var att in mappedKeys) {
      str += att+": "+mappedKeys[att].description+"<br />";
      function assignKey() {
        var mAtt = att;
        $(document).bind('keyup',mAtt,
          function () {
            keyMapPopUp.dialog('close');
            mappedKeys[mAtt].action();
          }
        );
      }
      assignKey();
    }
    $(document).bind('keyup','k',keyDialogClose);
    keyMapPopUp.html(str);
    keyMapPopUp.dialog('open');
  }
  var initLinkButtons = function() {
    $(".btn_link").each(function() {
      var lnk = $(this).attr('link_to');
      var key = $(this).attr('key_map');
      if(lnk) {
        $(this).click(function() {window.location=lnk;});
        if(key) {
          OpenChain.addKeyMap(key,$(this).html(),function() {window.location=lnk;});
          OpenChain.activateHotKeys();
        }
      }
    });
  }
  var initFormButtons = function() {
    $(".form_to").each(function() {
      var frm_id = $(this).attr('form_id');
      var key = $(this).attr('key_map');
      if(frm_id) {
        $(this).click(function() {$("#"+frm_id).submit();});
        if(key) {
          OpenChain.addKeyMap(key,$(this).html(),function() {$("#"+frm_id).submit();});
          OpenChain.activateHotKeys();
        }
      }
    });
  }
  var removeEmptyClassifications = function() {
    $(".classification_box").each(function() {
      var drop_me = true;
      if($(this).attr('must_submit')=="false") {
        $(this).find(':input[type!="hidden"][type!="button"]').each(function() {
          if($(this).is(':checked') || ($(this).attr('type')!='checkbox' && $(this).val().length>0 )) {
            drop_me = false;
          }
        });
        if(drop_me) {
          $(this).remove();
        }
      }
    });
  }
  var removeFromInvalidTariffs = function(hts_field) {
    hts_field.removeClass("error");
    var fieldId = hts_field.attr("id");
    var invalidPosition = jQuery.inArray(fieldId,invalidTariffFields);
    if(invalidPosition!=-1) {
      invalidTariffFields.splice(invalidPosition,1);
    }
  }
  var validateHTSFormat = function(hts) {
    if(hts.length<6) {
      return false;
    }
    if(hts.match(/[^0-9\. ]/)!=null) {
      return false;
    }
    return true;
  }
  var writeScheduleBMatches = function(htsField) {
    var col, schedBField;
    col = htsField.attr("col");
    schedBField = htsField.parents(".tf_row").find('input.sched_b_field[col="'+col+'"]')
    if(schedBField.length) {
      $.getJSON('/official_tariffs/schedule_b_matches?hts='+htsField.val(),function(data) {
        var to_write = schedBField.siblings('.sched_b_options');
        if(to_write.length==0) {
          schedBField.closest("td").append("<div class='sched_b_options'></div>");
          to_write = schedBField.siblings('.sched_b_options');
        }
        var h = "";
        var sb;
        for(var i=0; i<data.length; i++) {
          sb = data[i].official_schedule_b_code
          h += "<div class='sched_b_opt'><a href='#' class='sched_b_option'>"+sb.hts_code+"</a><br />";
          h += sb.short_description+"<br />";
          h += "<a href='#' class='lnk_schedb_popup' schedb='"+sb.hts_code+"'>info</a>";
        }
        to_write.html(h);
      }); 
    }
  }
  var validateOfficialValue = function(uri,hts_field,writeDataFunction) {
    var get_result_box = function() {
      var to_write = hts_field.siblings(".tariff_result");
      if(to_write.length==0) {
        hts_field.closest("td").append("<div class='tariff_result'></div>");
        to_write = hts_field.siblings(".tariff_result"); 
      }
      return to_write;
    }
    var invalid_callback = function() {
      invalidTariffFields.push(hts_field.attr("id"));
      hts_field.addClass("error");
      var to_write = get_result_box();
      to_write.html("Invalid tariff number.");
    }
    var valid_callback = function(data) {
      hts_field.removeClass("error");
      writeTariffInfo(data);
      if(hts_field.hasClass("hts_field")) {
        writeScheduleBMatches(hts_field);
      }
    }
    var writeTariffInfo = function(data) {
      var t, h, to_write;
      to_write = get_result_box();
      h = writeDataFunction(data);
      to_write.html(h);
    }
    removeFromInvalidTariffs(hts_field);
    var hts = hts_field.val();
    if(hts.length==0) {
      $(this).removeClass("error");
      get_result_box().html("");
      return;
    }
    if(!validateHTSFormat(hts)) {
      invalid_callback();
      return;
    }
    $.getJSON(uri,function(data) {
      if(data==null) {
        invalid_callback();
      }
      else {
        valid_callback(data);
      }
    });
  }
  var validateHTSValue = function(country_id,hts_field) {
    var wdf = function(data) {  
      if(data!="country not loaded") {
        var t = data.official_tariff;
        var h = t.remaining_description+"<br />"; 
        if(t.common_rate) {
          h+="Common Rate: "+t.common_rate+"<br />";
        } else {
          if(t.general_rate) {
            h+="General Rate: "+t.general_rate+"<br />";
          }
          if(t.erga_omnes_rate) {
            h+="Erga Omnes Rate: "+t.erga_omnes_rate+"<br />";
          }
          if(t.most_favored_nation_rate) {
            h+="MFN Rate: "+t.most_favored_nation_rate+"<br />";
          }
        }
        if(t.general_preferential_tariff_rate) {
          h+="GPT Rate: "+t.general_preferential_tariff_rate+"<br />";
        }
        if(t.import_regulations) {
          h+="Import Regulations: "+t.import_regulations+"<br />";
        }
        if(t.export_regulations) {
          h+="Export Regulations: "+t.export_regulations+"<br />";
        }
        h+="<a href='#' class='lnk_tariff_popup' country='"+country_id+"' hts='"+t.hts_code+"'>info</a>";
      }
      return h;
    }
    validateOfficialValue('/official_tariffs/find?hts='+hts_field.val()+'&cid='+country_id,hts_field,wdf)
  }
  var validateScheduleBValue = function(hts_field) {
    var wdf = function(data) {
      var h, t;
      h = "";
      if(data) {
        t = data.official_schedule_b_code;
        h = t.short_description+"<br />"
        h += "<a href='#' class='lnk_schedb_popup' schedb='"+t.hts_code+"'>info</a>";
      }
      return h;
    }

    validateOfficialValue('/official_tariffs/find_schedule_b?hts='+hts_field.val(),hts_field,wdf);
  }

  var pollingId;
  var pollForMessages = function(user_id) {
    $.getJSON('/messages/message_count?user_id='+user_id,function(data) {
      if(data>0) {
        $('#message_envelope').show();
      } else {
        $('#message_envelope').hide();
      }
    });
    return setInterval(function() {
        $.getJSON('/messages/message_count?user_id='+user_id,function(data) {
          if(data>0) {
            $('#message_envelope').show();
          } else {
            $('#message_envelope').hide();
          }
        });
      }, 30000
    );
  }

  var renderMilestones = function(parentContainer,milestoneSetJson,headingModule,isAdmin) { 
    var mfs = milestoneSetJson.milestone_forecast_set;
    var ident = mfs.piece_set.identifiers[headingModule];
    var h = "<table class='ms_tbl'><tr class='milestone_subhead'><td colspan='5' class='ms_"+mfs.state.toLowerCase()+"'>";
    h += ident ? (ident.label+": "+ident.value) : "&nbsp";
    h += "</td></tr>";
    for(var i=0;i<mfs.milestone_forecasts.length;i++) {
      var mf = mfs.milestone_forecasts[i]
      h += "<tr><td class='ms_col_1'></td><td class='ms_col_2'>"+mf.label+"</td><td class='ms_"+mf.state.toLowerCase()+" ms_col_date'>"+(mf.actual ? mf.actual : "")+"</td><td class='ms_col_date'>"+(mf.forecast ? mf.forecast : "")+"</td><td class='ms_col_date'>"+(mf.planned ? mf.planned : "")+"</td></tr>";
    }
    h += "<tr class='ms_action_links'><td colspan='5'>";
    if(mfs.can_change_plan) {
      h += "<a href=\"javascript:OpenChain.changePlan("+mfs.id+",'"+parentContainer.attr('id')+"','"+headingModule+"',"+isAdmin+");\">Change Plan</a> | ";
    }
    if(isAdmin) {
     h += "<a href=\"javascript:OpenChain.replanMilestone("+mfs.id+",'"+parentContainer.attr('id')+"','"+headingModule+"',"+isAdmin+");\">Replan</a>";
    }
    h += "</td></tr></table>";
    parentContainer.html(h);
  }
  var orderLineMilestones = function(parentContainer,orderLineId,isAdmin) {
    $.getJSON('/milestone_forecast_sets/show_by_order_line_id?line_id='+orderLineId,function(data) {
      parentContainer.hide();
      var h = "<table class='ms_tbl'><thead><tr><th width='40%'>Milestone</th><th width='20%'>Actual</th><th width='20%'>Forecast</th><th width='20%'>Plan</th></tr></table>";
      for(var i=0;i<data.length;i++) {
        h += "<div id='mfs_"+data[i].milestone_forecast_set.id+"'/>";
      }
      parentContainer.html(h);
      for(i=0;i<data.length;i++) {
        renderMilestones($("#mfs_"+data[i].milestone_forecast_set.id),data[i],'shipment',isAdmin);
      }
      parentContainer.fadeIn('slow');
    });                  
  }
  var showChangePlan = function(dialogContainer,parentContainer,milestoneSetId,headingModule,isAdmin) {
    dialogContainer.dialog('destroy');
    dialogContainer.dialog({modal:true,buttons:{"OK":function() {
      dialogContainer.dialog('close');
      $.post('/milestone_forecast_sets/'+milestoneSetId+'/change_plan',{plan_id:$("#sel_plan").val(),authenticity_token:authToken},function(data) {
        renderMilestones(parentContainer,data,headingModule,isAdmin);
      });
    }}});
  }
  var initScheduleBLinks = function() {
    $(".lnk_schedb_popup").live('click',function(evt) {
      evt.preventDefault();
      scheduleBPopUp($(this).attr("schedb"));
    }); 
  }
  var scheduleBPopUp = function(hts) {
    var mp = $("#mod_sched_b");
    if(!mp.length) {
      $("body").append("<div id='mod_sched_b' style='display:none;'><div id='sched_b_cont'>Loading Schedule B Data</div></div>")
      mp = $("#mod_sched_b");
      mp.dialog({autoOpen:false,width:'400',height:'500',buttons:{"OK":function() {$("#mod_sched_b").dialog('close');}}});
    }
    var c = $("#sched_b_cont");
    c.html("Loading Schedule B Data");
    mp.dialog('open');
    $.ajax({
      url:'/official_tariffs/find_schedule_b?hts='+hts,
      dataType:'json',
      error: function(req,msg,obj) {
        c.html("We're sorry, an error occurred while trying to load this information.");

      },
      success: function(data) {
        var h = '';
        if(data==null) {
          h = "No data was found for tariff "+hts;
        } else {
          var o = data.official_schedule_b_code;
          h = "<table class='tbl_hts_popup'><tbody>";
          h += htsDataRow("Tariff #:",o.hts_code);
          h += htsDataRow("Short Description:",o.short_description);
          h += htsDataRow("Long Description:",o.long_description);
          h += htsDataRow("Quantity 1",o.quantity_1);
          h += htsDataRow("Quantity 2",o.quantity_2);
          h += htsDataRow("SITC Code",o.sitc_code);
          h += htsDataRow("End Use Classification",o.end_use_classification);
          h += htsDataRow("USDA Code",o.usda_code);
          h += htsDataRow("NAICS Classification",o.naics_classification);
          h += htsDataRow("HiTech Classification",o.hitech_classification);
          h += "</tbody></table>";
        }
        c.html(h);
      }
    });
  }

  var initEntitySnapshotPopups = function() {
    $("a.entity_snapshot_popup").live('click',function(evt) {
      var modal, inner;
      evt.preventDefault();
      modal = $("#mod_entity_snapshot");
      if(modal.length==0) {
        $("body").append("<div id='mod_entity_snapshot'><div id='mod_entity_snapshot_inner'>Loading...</div></div>")
        modal = $("#mod_entity_snapshot");
        modal.dialog({title:"Snapshot",autoOpen:false,width:'400',height:'500',buttons:{"Close":function() {$("#mod_entity_snapshot").dialog('close');}}});
      }
      inner = $("#mod_entity_snapshot_inner");
      inner.html('Loading...');
      modal.dialog('open');
      $.get('/entity_snapshots/'+$(this).attr('entity_snapshot_id'),function(data) {inner.html(data);});
    });
  }

  var showPreviewDialog = function(html,dialogTitle) {
    var dt = dialogTitle ? dialogTitle : "Preview";
    $("body").append("<div id='pt_preview' style='display:none;'>"+html+"</div>");
    $("#pt_loading").dialog('close');
    $("#pt_preview").dialog({autoOpen:true,
      title:dt,
      width:"auto",
      modal:true,
      buttons:{"OK":function() {
        $("#pt_preview").dialog('close'); 
        $("#pt_preview").remove();
       }}});
    $("#pt_loading").remove();
  }
  var dropTableHandlers = new Object();
  var handleRowDrop = function(table,row) {
    var handler = dropTableHandlers[$(table).attr('id')];
    if(handler) {
      handler(table,row);
    }
  }
  return {
    //public stuff
    ajaxAutoClassify: function(column,baseCountry,hts) {
      var loadingMessage = "Loading Auto-Classification";
      $("div.auto_class_results.class_col_"+column).not(".cntry_"+baseCountry).html(loadingMessage);
      $.get('/official_tariffs/auto_classify/'+hts.replace(/\./g,''),function(data) {
        var i,j,d,iso,hts,html;
        for(i=0;i<data.length;i++) {
          d = data[i];
          iso = d['iso'];
          if(iso==baseCountry) {
            continue;
          }
          html = "";
          for(j=0;j<d['hts'].length;j++) {
            hts = d['hts'][j];
            html += "<a href='#' class='hts_option'>"+hts.code+"</a>";
            html += "&nbsp;[<a href='#' class='lnk_tariff_popup' iso='"+iso+"' hts='"+hts.code+"'>info</a>]";
            html += "<br />"+hts.desc+"<br />"+"Common Rate: "+hts.rate+"<br />";
          }
          $("div.auto_class_results.class_col_"+column+".cntry_"+iso).html(html);
        }
        $("div.auto_class_results.class_col_"+column).not(".cntry_"+baseCountry).each(function() {
          if($(this).html()==loadingMessage) {
            $(this).html("No auto-classifications were found.");
          }
        });
      });
    },
    setAuthToken: function(t) {
      authToken = t;
    },
    changePlan: function(milestoneSetId,parentContainerId,headingModule,isAdmin) {
      var mp = $("#mod_loading_plans");
      if(!mp.length) {
        $("body").append("<div id='mod_loading_plans' style='display:none;'>Loading Milestone Plans...</div>");
        mp = $("#mod_loading_plans")
      }
      var md = $("#mod_pick_plan");
      if(!md.length) {
        $.get('/milestone_plans.json',function(plans) {
          var h = "<div id='mod_pick_plan' style='display:none;'><select id='sel_plan'><option value=''>Select A Plan</option>";
          for(var i=0;i<plans.length;i++) {
            h += "<option value='"+plans[i].milestone_plan.id+"'>"+plans[i].milestone_plan.name+"</option>";
          }
          h += "</select></div>";
          $("body").append(h);
          $("#mod_pick_plan").dialog({autoOpen:false,modal:true});
          showChangePlan($("#mod_pick_plan"),$("#"+parentContainerId),milestoneSetId,headingModule,isAdmin);
        });
      } else {
        showChangePlan(md,$("#"+parentContainerId),milestoneSetId,headingModule,isAdmin);
      }
      return false;
    },
    replanMilestone: function(milestoneSetId,parentContainerId,headingModule,isAdmin) {
      if(window.confirm("Are you sure? Replanning will reset all planned dates.  There is no undo for this action.")) {
        var parentContainer = $("#"+parentContainerId);
        parentContainer.fadeOut('slow').html('Replanning...').fadeIn('slow');
        $.post('/milestone_forecast_sets/'+milestoneSetId+'/replan',function(data) {
          parentContainer.hide();
          renderMilestones(parentContainer,data,headingModule,isAdmin);
          parentContainer.fadeIn('slow');
        });              
      }
      return false;
    },
    showOrderLineDetail: function(orderLineId,isAdmin) {
      var detRow = $("#det_"+orderLineId);
      var mCont = detRow.find(".milestones_cont");
      mCont.html("Loading Milestones...");
      detRow.fadeIn('slow');
      orderLineMilestones(mCont,orderLineId,isAdmin);
    },
    loadUserList: function(destinationSelect,selectedId) {
      $.getJSON('/users.json',function(data) {
        var i, company, j, u, selected;
        var h = "";
        for(i=0;i<data.length;i++) {
          company = data[i].company;
          if(company.users.length==0) {
            continue;
          }
          h += "<optgroup label='"+company.name+"'>"
          for(j=0;j<company.users.length;j++) {
            u = company.users[j];
            selected = (u.id==selectedId ? "selected=\'true\' " : "");
            h += "<option value='"+u.id+"' "+selected+">"+u.full_name+"</option>";
          }
          h += "</optgroup>";
        }
        destinationSelect.html(h);
      });
    },
    hideByEntityType: function(table,entityTypeId) {
      table.find('.fld_lbl').each(function() {$(this).parents(".field_row:first").fadeIn('slow');});
      if(entityTypeId.length) {
        table.find('.fld_lbl').not('[entity_type_ids*="*'+entityTypeId+'*"]').each(function() {
          $(this).parents(".field_row:first").not(".neverhide").hide(); 
        });
      }
    },
    raiseTooltip: function(tip) {
      tip.css('z-index','5000');
      $("body").append(tip);
      return true;
    },
    addKeyMap: function(key,desc,act) {
      mappedKeys[key]=new Object();
      mappedKeys[key].description = desc;
      mappedKeys[key].action = act;
    },
    activateHotKeys: function() {
      if(!keyMapPopUp) {
        $("body").append("<div id='mod_keymap'></div>");
        keyMapPopUp = $("#mod_keymap");
        keyMapPopUp.dialog({autoOpen:false,width:'auto',title:"Action Keys",
          beforeClose: function() {
            unbindKeys();
          }});
        $(document).bind('keyup','k',showKeyboardMapPopUp);
        $("#footer").append("<div style='text-align:center'>This page has action keys. Press &quot;k&quot; to activate.</div>");
      }
    },
    //keymapping shortcut to pass an object id and have it clicked when the user uses the hotkey
    addClickMap: function(key,desc,object_id) {
      OpenChain.addKeyMap(key,desc,function() {$("#"+object_id).click();});
    },
    initDragTables: function() {
      $("table.drag_table tr:even").addClass("drag_table_alt_row");
      $("table.drag_table").tableDnD({dragHandle:'drag_handle',onDrop:function(table,row) {handleRowDrop(table,row);}});
    },
    //registers a function to be called when the given drag_table's row is dropped
    //callback should be function(table,row)
    registerDragTableDropHandler: function(table,handler) {
      dropTableHandlers[table.attr('id')] = handler;
    },
    initClassifyPage: function() {
      $(".tf_remove").live('click',function(ev) {
        $(this).closest(".tf_row").find(".hts_field").each(function() {removeFromInvalidTariffs($(this));});
        $(this).closest(".tf_row").find(".sched_b_field").each(function() {removeFromInvalidTariffs($(this));});
        destroy_nested('tf',$(this));
        ev.preventDefault();
      });
      $("a.hts_option").live('click',function(ev) {
        ev.preventDefault();
        $(this).parents(".hts_cell").find("input.hts_field").val($(this).html());
      });
      $("a.auto_class").live('click',function(ev) {
        ev.preventDefault();
        var found = false;
        $(this).parents(".tf_row").find("input.hts_field").each(function() {
          var inp = $(this);
          if(inp.val().length > 0) {
            found = true;
            OpenChain.ajaxAutoClassify(inp.attr('col'),inp.attr('country_iso'),inp.val());
          }
        });
        if(!found) {
          window.alert("You must enter at least one HTS number in order to Auto-Classify.");
        }
      });
      $("a.sched_b_option").live('click',function(ev) {
        ev.preventDefault();
        $(this).closest("td").find("input.sched_b_field").val($(this).html());
      });
      $("form").submit(function() {
        if(invalidTariffFields.length>0) {
          window.alert("Please fix or erase invalid tariff numbers.");
          return false;
        }
        removeEmptyClassifications();
        $(".tf_row").each(function() {
          var has_data = false;
          $(this).find(".hts_field, .sched_b_field").each(function() {
            if(!has_data) {
              has_data = $(this).val().length>0;
            }
          });
          if(!has_data) {
            $(this).find(".tf_remove").each(function() {
              destroy_nested('tf',$(this));
            });
          }
        });
      });
      $(".sched_b_field").live('blur',function() {validateScheduleBValue($(this));});
      $(".sched_b_field").each(function() {validateScheduleBValue($(this));});
      $(".hts_field").live('blur',function() {validateHTSValue($(this).attr('country'),$(this))});
      $(".hts_field").each(function() {validateHTSValue($(this).attr('country'),$(this))});
    },
    add_tf_row: function(link,parent_index,country_id) {
      my_index = new Date().getTime();
      content = "<tr class=\"tf_row\">"
      content += "<td><input id='product_classifications_attributes_"+parent_index+"_tariff_records_attributes_"+my_index+"_line_number' name='product[classifications_attributes]["+parent_index+"][tariff_records_attributes]["+my_index+"][line_number]' size='3' type='text' /></td>";
      for(i=1; i<4; i++) {
        content += "<td><input id=\"product_classifications_attributes_"+parent_index+"_tariff_records_attributes_"+my_index+"_hts_"+i+"\" name=\"product[classifications_attributes]["+parent_index+"][tariff_records_attributes]["+my_index+"][hts_"+i+"]\" type=\"text\" class='hts_field' country='"+country_id+"' /></td>"; 
      }
      content += "<td><input class=\"tf_destroy\" id=\"product_classifications_attributes_"+parent_index+"_tariff_records_attributes_"+my_index+"__destroy\" name=\"product[classifications_attributes]["+parent_index+"][tariff_records_attributes]["+my_index+"][_destroy]\" type=\"hidden\" value=\"false\" /><a href=\"#\" class=\"tf_remove\">Remove</a></td></tr>"
      link.parents('.add_row').before(content);
      link.parents('.tr_body').children('.tf_row').last().find('.hts_field').first().focus();
    },
    initAttachments: function() {
      $("#mod_attach").dialog({autoOpen:false,title:"Attach File",width:"auto",buttons:{
        "Attach":function() {$("#frm_attach").submit();},
        "Cancel":function() {$("#mod_attach").dialog('close');}
      }});
      $("#btn_add_attachment").click(function() {$("#mod_attach").dialog('open');});
    },
    disableMessagePolling: function() {
      clearInterval(pollingId) 
    },
    link_selects: function(wrapTableSelector) {
      var tbl, s_unselected, s_selected, l_unsel, l_sel;
      tbl = $(wrapTableSelector);
      s_unselected = tbl.find("select.unselected");
      s_selected = tbl.find("select.selected");
      tbl.find("a.unselect").click(function(evt) {
        evt.preventDefault();
        s_unselected.append(s_selected.find(":selected"));
      });
      tbl.find("a.select").click(function(evt) {
        evt.preventDefault();
        s_selected.append(s_unselected.find(":selected"));
      });
      
    },
    previewTextile: function(sourceSelector,dialogTitle,preHtml,postHtml) {
      $("body").append("<div id='pt_loading' style='display:none;'>Loading preview.</div>");
      $("#pt_loading").dialog({modal:true,title:"Preview Loading",width:"auto",autoOpen:true});
      $.ajax({url:"/textile/preview",type:'POST',data:{c:$(sourceSelector).val()},
        success:function(data) { 
          var h = "";
          if(preHtml) {
            h += preHtml;
          }
          h += data;
          if(postHtml) {
            h += postHtml;
          }
          showPreviewDialog(h,dialogTitle);
        },
        error:function() {
          showPreviewDialog("There was an error on the server an the preview failed.  Please try again.","ERROR");
        }
      });
    },
    init: function(user_id) {
      initLinkButtons();
      initFormButtons();
      initRemoteValidate();
      initScheduleBLinks();
      initEntitySnapshotPopups();
      //initInfiniteScroll();
      if(user_id) {
        pollingId = pollForMessages(user_id);
      }
    }
  };
})();
var OCSurvey = (function() {
  return {
    addQuestion: function(id,content,choices,warning) {
      var mid = id ? id : new Date().getTime();
      var h = "<div class='question_box' id='q-"+mid+"' style='display:none;'>";
      if(id && id < 10000000) {
        h += "<input type='hidden' name='survey[questions_attributes]["+mid+"][id]' value='"+mid+"' />";
      }
      h += "<div id='qb-"+mid+"'>Question Body:</div><textarea id='q_"+mid+"' class='q_area' name='survey[questions_attributes]["+mid+"][content]' rows='8'>"+content+"</textarea><br/>";
      h += "<a href='#' class='q_preview' qid='"+mid+"'>Preview</a><br />";
      h += "Possible Answers: (put one answer on each line)<br/><textarea id='qc_"+mid+"'class='q_area' name='survey[questions_attributes]["+mid+"][choices]' rows='3'>"+choices+"</textarea>";
      h += "<div><input id='qw_"+mid+"'type='checkbox' name='survey[questions_attributes]["+mid+"][warning]' value='1' "+(warning ? "checked='checked'" : "")+"/> Warn If Empty</div>"
      h += "<div style='text-align:right;'><a href='#' class='copy_ques' qid='"+mid+"'>Copy</a> | <a href='#' class='del_ques' qid='"+mid+"'>Delete</a></div>";
      h += "</div>";
      $("#questions").append(h);
      $("#q-"+mid).slideDown('slow');
      $("#qb-"+mid).effect("highlight",{color:"#1eb816"},2000);
    },
    copyQuestion: function(id) {
      var mid = new Date().getTime();
      OCSurvey.addQuestion(mid,$("#q_"+id).val(),$("#qc_"+id).val(),$("#qw_"+id));
      $('html, body').animate({scrollTop: $("#q-"+mid).offset().top}, 'slow');
    }
  }
})();
var OCInvoice = (function() {
  return {
    init: function() {
      $('.cc_fld').live('change',function() {
        var rw = $(this).parents('tr');
        var sel = $(this).find('option:selected');
        rw.find('.desc_fld').val(sel.attr('desc'));
        rw.find('.hst_fld').val(sel.attr('hst'));
      });
    },
    addInvoiceLine: function(parentTable,chargeCodes) {
      var mt = new Date().getTime();
      var namePre = "broker_invoice[broker_invoice_lines_attributes]["+mt+"]"; 
      var h = "<tr><td>";
      h+="<select class='inv_det_fld cc_fld' name='"+namePre+"[charge_code]'>";
      $.each(chargeCodes,function(i,v) {h+="<option value='"+v.code+"' desc='"+v.desc+"' hst='"+v.hst+"'>"+v.code+"</option>";});
      h+="</select></td>";
      h+="<td><input type='text' size='30' class='inv_det_fld desc_fld' name='"+namePre+"[charge_description]'/></td>";
      h+= "<td><input type='text' size='30' class='inv_det_fld decimal' name='"+namePre+"[charge_amount]'/></td>";
      h+= "<td><input type='text' size='30' class='inv_det_fld decimal hst_fld' name='"+namePre+"[hst_percent]'/></td>";
      h+= "<td><a href='#' class='inv_det_del'><img src='/images/x.png' alt='delete'/></a></td></tr>";
      $(parentTable+" tbody").append(h);
      $(".decimal").jStepper();
    }
  }
})();
$( function() {
    $("a.click_sink").live('click',function(evt) {evt.preventDefault();});
    OpenChain.init(OpenChain.user_id);
    $(".decimal").jStepper();
    $(".integer").jStepper({allowDecimals:false});
    $("#lnk_hide_notice").click(function(ev) {
      ev.preventDefault();
      $('#notice').hide();
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
        OpenChain.raiseTooltip(this.getTip());
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
      var c_iso = $(this).attr('iso')
      tariffPopUp(hts,c_id,c_iso);
    });
});
$(document).ready( function() {
    OpenChain.initDragTables();
    handleCustomFieldCheckboxes();
    $(':checkbox').css('border-style','none');
    $('#notice').slideDown('slow');
    $('.focus_first').focus();

    //make the shared/search_box partial work
    setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));

    //Hide subscriptions buttons until feature is better implemented (ticket 87)
    $("#btn_subscriptions").hide();
    
    //when closing a dialog, make sure to take focus from all inputs
    $("div.ui-dialog").live( "dialogbeforeclose", function(event, ui) {
      $(this).find(":input").blur();
    });
    if(!$.support.boxModel) {
      $("#two_col_action").find("span.ui-button-text").each(function() {$(this).html($(this).html().replace(/ /,'<br />'));});
    }
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
        appendSelect(con_select,'contains','contains');
        appendSelect(con_select,'eq','equals');
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
    includeName: true
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
  OpenChain.addClickMap(isSalesOrder ? 'l' : 'o','Add '+(isSalesOrder ? 'Sale' : 'Order'),'btn_add_order');
  OpenChain.addClickMap('r','Add Product','btn_add_line');
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
      h+="<tr><td><input type='hidden' name='[lines]["+i+"][linked_sales_order_line_id]' value='"+line.id+"'/>"+line.line_number+"</td><td>"+line.product.name+"<input type='hidden' name='[lines]["+i+"][product_id]' value='"+line.product.id+"'/></td><td>"+line.quantity+"</td><td><input type='text' name='[lines]["+i+"][quantity]' mf_id='delln_delivery_qty' class='decimal rvalidate'/></td></tr>";
    }
    h += "</tbody></table>";
    $("#div_pack_order_content").html(h);
    $(".decimal").jStepper();
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
      h+="<tr><td><input type='hidden' name='[lines]["+i+"][linked_order_line_id]' value='"+line.id+"'/>"+line.line_number+"</td><td>"+line.product.name+"<input type='hidden' name='[lines]["+i+"][product_id]' value='"+line.product.id+"'/></td><td>"+line.quantity+"</td><td><input type='text' name='[lines]["+i+"][quantity]' mf_id='shpln_shipped_qty' class='decimal rvalidate'/></td></tr>";
    }
    h += "</tbody></table>";
    $("#div_pack_order_content").html(h);
    $(".decimal").jStepper();
  });
}
function tariffPopUp(htsNumber,country_id,country_iso) {
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
  var u = '/official_tariffs/find?hts='+htsNumber;
  if(country_id) {
    u += "&cid="+country_id;
  } else if (country_iso) {
    u += "&ciso="+country_iso;
  }
  $.ajax({
    url:u,
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
        h += htsDataRow("Common Rate:",o.common_rate);
        h += htsDataRow("General Rate:",o.general_rate);
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
        h += htsDataRow("Import Regulations:",o.import_regulations);
        h += htsDataRow("Export Regulations:",o.export_regulations);
        if(o.binding_ruling_url) {
          h += htsDataRow("Binding Rulings:","<a href='"+o.binding_ruling_url+"' target='rulings'>Click Here</a>");
        }
        if(o.official_quota!=undefined) {
          h += htsDataRow("Quota Category",o.official_quota.category);
          h += htsDataRow("SME Factor",o.official_quota.square_meter_equivalent_factor);
          h += htsDataRow("SME UOM",o.official_quota.unit_of_measure);
        }
        h += htsDataRow("Notes:",o.notes);
        if(o.auto_classify_ignore) {
          h += htsDataRow("Ignore For Auto Classify","Yes")
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

function next_action_to_form(form) {
  hidden_to_form(form,"c_next","true");
}
function previous_action_to_form(form) {
  hidden_to_form(form,"c_previous","true");
}
function hidden_to_form(form,name,value) {
  form.append("<input type='hidden' name='"+name+"' value='"+value+"' />");
}
