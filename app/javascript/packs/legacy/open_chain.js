var OpenChain = (function() {
  //private stuff
  var mappedKeys = new Object();
  var keyMapPopUp = null;

  var initRemoteValidate = function() {
    $('body').on('change',"input.rvalidate",function() {
        remoteValidate($(this));
    });
    $("body").on('submit','form',function(ev) {
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
    // Only init a tooltip when we haven't already done so for a field
    if (field.parent().data("tooltip") === undefined) {
      field.parent().tooltip({items: "img.val_status"});
    }

    field.nextAll(".val_status").remove();
    field.after("<i class='fa fa-circle-o-notch fa-spin val_status'></i>");
    field.next().fadeIn();
    $.getJSON('/field_validator_rules/validate',{mf_id: mf_id, value: field.val()},function(data) {
      field.nextAll(".val_status").remove();
      if(data.length) {
        var m = "";
        $.each(data,function(i,v) {m += v+"<br />"});
        field.addClass("error");
        field.after("<i class='fa fa-exclamation-circle val_status error'></i>");
        field.parent().tooltip("option", "content", m);
      } else {
        field.removeClass("error");
      }
    });
  }

  var keyDialogClose = function() {keyMapPopUp.dialog('close');}
  var unbindKeys = function() {
    $(document).unbind('keyup');
    Chain.bindBaseKeys();
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
      if(lnk && key) {
        OpenChain.addKeyMap(key,$(this).html(),function() {window.location=lnk;});
        OpenChain.activateHotKeys();
      }
    });
  }
  var initFormButtons = function() {
    $(".form_to").each(function() {
      var frm_id = $(this).attr('form_id');
      var key = $(this).attr('key_map');
      if(frm_id) {
        submitForm = function (e) {
          // This prevents double form submissions in several cases
          e.preventDefault();
          $("#"+frm_id).submit();
        }
        $(this).click(submitForm);
        if(key) {
          OpenChain.addKeyMap(key,$(this).html(), submitForm);
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
      if(data.length>0) {
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
      }
    });
  }
  var showChangePlan = function(dialogContainer,parentContainer,milestoneSetId,headingModule,isAdmin) {
    dialogContainer.dialog('destroy');
    dialogContainer.dialog({modal:true,buttons:{"OK":function() {
      dialogContainer.dialog('close');
      $.post('/milestone_forecast_sets/'+milestoneSetId+'/change_plan',{plan_id:$("#sel_plan").val()},function(data) {
        renderMilestones(parentContainer,data,headingModule,isAdmin);
      });
    }}});
  }

  var initEntitySnapshotPopups = function() {
    $('body').on('click',"a.entity_snapshot_popup",function(evt) {
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
      $.get('/official_tariffs/auto_classify/'+hts.replace(/\./g,'')+'.json',function(data) {
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
            if(hts.use_count > 0) {
              html += "&nbsp;<span class='badge badge-info' title='This tariff number is used about "+numberWithCommas(hts.use_count)+" times.' data-toggle='tooltip'>"+abbrNum(hts.use_count,2)+"</span>";
            }
            html += "&nbsp;<a href='#' class='lnk_tariff_popup btn btn-sm' iso='"+iso+"' hts='"+hts.code+"'>info</a>";
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
      detRow.fadeIn('slow');
      orderLineMilestones(mCont,orderLineId,isAdmin);
    },
    //tested
    loadUserList: function(destinationSelect,selectedId) {
      Chain.loadUserList(destinationSelect,selectedId);
    },
    hideByEntityType: function(table,entityTypeId) {
      table.find('.fld_lbl').each(function() {$(this).parents(".field_row:first").fadeIn('slow');});
      if(entityTypeId.length) {
        table.find('.fld_lbl').not('[entity_type_ids*="*'+entityTypeId+'*"]').each(function() {
          $(this).parents(".field_row:first").not(".neverhide").hide();
        });
      }
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
        keyMapPopUp.dialog({autoOpen:false,position:'center',width:'auto',title:"Action Keys",
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
      $("body").on('click','.tf_remove',function(ev) {
        $(this).closest(".tf_row").find(".hts_field").each(function() {Classify.removeFieldFromInvalidTariffList($(this));});
        $(this).closest(".tf_row").find(".sched_b_field").each(function() {Classify.removeFieldFromInvalidTariffList($(this));});
        destroy_nested('tf',$(this));
        ev.preventDefault();
      });
      $('body').on('click',"a.auto_class",function(ev) {
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
      $("form").submit(function() {
        if(Classify.hasInvalidTariffs()) {
          if (window.confirm("This Product has invalid tariffs.  It is strongly advised that you fix or remove them.  Are you sure you want to update it without resolving this issue?")) {
            $("form").find("input[mf_id*='hts_hts']").removeClass("error");
            return true;
          }
          return false;
        }
        removeEmptyClassifications();
      });
      Classify.enableHtsChecks();
      Chain.htsAutoComplete("input.hts_field");
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
      initEntitySnapshotPopups();
    }
  };
})();
var OCSurvey = (function() {
  return {
    addQuestion: function(id,content,choices,attachments,warning, require_comment, require_attachment, attachment_required_for_choices, comment_required_for_choices) {
      var mid = id ? id : new Date().getTime();
      var h = "<div class='question_box' id='q-"+mid+"' style='display:none;'>";

      if(id && id < 10000000) {
        h += "<input type='hidden' name='survey[questions_attributes]["+mid+"][id]' value='"+mid+"' />";
      }
      h += "<div id='qb-"+mid+"'><img src='/assets/drag_handle.gif' alt='move' class='question_handle'/>Question Body:</div><textarea id='q_"+mid+"' class='q_area' q-id='"+mid+"' name='survey[questions_attributes]["+mid+"][content]' rows='8'>"+content+"</textarea><br/>";
      h += "<div style='display:none;' id='q_error_"+mid+"' class='text-danger'></div>";
      h += "<a href='#' class='q_preview' qid='"+mid+"'>Preview</a><br />";
      h += "Possible Answers: (put one answer on each line)<br><textarea id='qc_"+mid+"'class='q_area' name='survey[questions_attributes]["+mid+"][choices]' rows='3'>"+choices+"</textarea>";
      h += "<input type='hidden' name='survey[questions_attributes]["+mid+"][rank]' value=''/>"
      h += "<div><input id='qw_"+mid+"'type='checkbox' name='survey[questions_attributes]["+mid+"][warning]' value='1' "+(warning ? "checked='checked'" : "")+"> Require respondent to select an answer OR if no answers are given above, require a comment?</div>"
      h += "<div><input id='rc_"+mid+"'type='checkbox' name='survey[questions_attributes]["+mid+"][require_comment]' value='1' "+(require_comment ? "checked='checked'" : "")+"> Require respondent to add a comment?</div>"
      h += "Require respondent to add a comment if choice is one of:<br><textarea id='rafc_"+mid+"' name='survey[questions_attributes]["+mid+"][comment_required_for_choices]' rows='3'>" + (comment_required_for_choices ? comment_required_for_choices : "")+ "</textarea>"
      h += "<div><input id='ra_"+mid+"'type='checkbox' name='survey[questions_attributes]["+mid+"][require_attachment]' value='1' "+(require_attachment ? "checked='checked'" : "")+"> Require respondent to add an attachment?</div>"
      h += "Require respondent to add an attachment if choice is one of:<br><textarea id='rafc_"+mid+"' name='survey[questions_attributes]["+mid+"][attachment_required_for_choices]' rows='3'>" + (attachment_required_for_choices ? attachment_required_for_choices : "") + "</textarea>"


      h += "<div id='qa_"+mid+"'><div class='row'><div class='col-md-12'><h4>Attachments</h4></div></div>"
      if (typeof(attachments) != "undefined" && attachments != null){
        $.each(attachments, function(index, value){
          h += "<div class='row'><div class='col-md-12' style='padding-left:30px;'>"
          h += "<a href='/attachments/"+value[0]+"/download' target='_blank'>"+value[1]+"</a>"
          h += "</div></div>"
        });
      }

      h += "<div>"
      h += "<div class='row'><div class='col-md-12'>"
      h += "<div class='col-4'>"
      h += "<input style='float: left; margin-right: 20px;' id='q-attach-input-"+mid+"' type='file' size='60' name='survey[questions_attributes]["+mid+"][attachments_attributes][attachment][attached]' class='form-control'>"
      h += "</div>"
      h += "<div class='col-2' id='q-upload-attachment-button'>"
      h += "</div></div></div></div></div>"

      h += "<div style='text-align:right;'><a href='#' class='copy_ques' qid='"+mid+"'>Copy</a> | <a href='#' class='del_ques' qid='"+mid+"'>Delete</a></div>";
      h += "</div>";
      $("#questions").append(h);
      $("#q-"+mid).slideDown('slow');
      $("#qb-"+mid).effect("highlight",{color:"#1eb816"},2000);
      $("#q-attach-input-"+mid).on("change", function(){
        if ($(this).val()!=""){
          //File was chosen, so present user with a remove button
          remove_button = "<button id='q-remove-attachment-"+mid+"' style='margin-top: 2px;' type='button' class='btn btn-sm btn-danger'>Remove</button>"
          if ($('#q-remove-attachment-'+mid).length == 0) { //if there was no button already...
            $("#q-upload-attachment-button").append(remove_button)
            $('#q-remove-attachment-'+mid).click(function(){
              //bind the click to (1) remove attachment, (2) remove button
              $('#q-attach-input-'+mid).val("")
              $(this).remove();
            });
          }
        }
        else{
          //File was removed by cancelling the file dialog; destroy the remove button
          $('#q-remove-attachment-'+mid).remove();
        }
      })
    },
    copyQuestion: function(id) {
      var mid = new Date().getTime();
      OCSurvey.addQuestion(mid,$("#q_"+id).val(),$("#qc_"+id).val(),null,$("#qw_"+id));
      $('html, body').animate({scrollTop: $("#q-"+mid).offset().top}, 'slow');
    }
  }
})();
$( function() {
    OpenChain.init(OpenChain.user_id);
    $(".decimal").jStepper();
    $(".integer").jStepper({allowDecimals:false});
    $(".btn_cancel_mod").click( function() {
        $.modal.close();
    });
    //.isdate must be before the tooltip call
    $(".isdate").datepicker({dateFormat: 'yy-mm-dd'});
    $(".fieldtip, .dialogtip").tooltip({
      position: {my: "left top", at: "left bottom+3"}
    });

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
      if(Classify.validateHTS($(this).val())) {
        $(this).removeClass("bad_data");
      } else {
        $(this).addClass("bad_data");
      }
    });
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
});
$(document).ready( function() {
    OpenChain.initDragTables();
    handleCustomFieldCheckboxes();
    $(':checkbox').css('border-style','none');
    $('.focus_first').focus();

    //make the shared/search_box partial work
    setSearchFields($("#srch_fields"),$("#srch_val"),$("#srch_cond"));

    //Hide subscriptions buttons until feature is better implemented (ticket 87)
    $("#btn_subscriptions").hide();

    //when closing a dialog, make sure to take focus from all inputs
    $(this).on( "dialogbeforeclose",'div.ui-dialog', function(event, ui) {
      $(this).find(":input").blur();
    });
    if(!$.support.boxModel) {
      $("#two_col_action").find("span.ui-button-text").each(function() {$(this).html($(this).html().replace(/ /,'<br />'));});
    }
});

function endsWith(str, suffix) {
    return $.inArray(suffix, str, str.length - suffix.length) !== -1;
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

function addHiddenFormField(parentForm,name,value,id,style_class) {
    $("<input type='hidden' name='"+name+"' value='"+value+"' id='"+id+"' class='"+style_class+"' />")
    .appendTo(parentForm);
}
function loading(wrapper) {
  wrapper.html('<i class="fa fa-circle-o-notch fa-spin"></i>');
}

//address setup
function setupShippingAddress(companyType,select,display,companyId,selected_val) {
   select.parent().on("change",'select',function(){
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
      if(options.includeName) { h = h+'<b>'+data.address.name+'</b><br/>'; }
      h = h + makeLine(data.address.line_1,true) + makeLine(data.address.line_2,true);
      if(data.address.city!=null && data.address.city.length>0) {
        h = h + data.address.city+',';
      }
      h = h + makeLine(data.address.state,false) + ' ' + makeLine(data.address.postal_code,false)
          + '<br/>' + makeLine(data.address.country==null ? "" : data.address.country.name,false);
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
  $("#btn_add_line").click(function() {
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
      h+="<tr><td><input type='hidden' name='[lines]["+i+"][linked_sales_order_line_id]' value='"+line.id+"'/>"+line.line_number+"</td><td>"+line.product.name+"<input type='hidden' name='[lines]["+i+"][delln_prod_id]' value='"+line.product.id+"'/></td><td>"+line.quantity+"</td><td><input type='text' name='[lines]["+i+"][delln_delivery_qty]' mf_id='delln_delivery_qty' class='decimal rvalidate'/></td></tr>";
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
function getOpenSalesOrders(callback) {
  $.getJSON("/sales_orders/all_open.json",callback);
}
function getOpenOrders(callback) {
  $.getJSON("/orders/all_open.json",callback);
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