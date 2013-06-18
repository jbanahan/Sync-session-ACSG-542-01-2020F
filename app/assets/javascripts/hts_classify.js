var Classify = (function() {

  var invalidTariffFields = [];

  var removeFromInvalidTariffs = function(hts_field) {
    hts_field.removeClass("error");
    var fieldId = hts_field.attr("id");
    var invalidPosition = $.inArray(fieldId,invalidTariffFields);
    if(invalidPosition!=-1) {
      invalidTariffFields.splice(invalidPosition,1);
    }
  }

  var validateHTSFormat = function(hts) {
    if(hts.length<6) {
      return false;
    }
    // Some countries (NZ for instance) do have letters in their HTS numbers.
    if(hts.match(/[^0-9A-Za-z\. ]/)!=null) {
      return false;
    }
    return true;
  }

  var writeScheduleBMatches = function(htsNumber,countryId,schedBField) {
    var col, schedBField;
    if(schedBField.length) {
      $.getJSON('/official_tariffs/schedule_b_matches?hts='+htsNumber,function(data) {
        if(data==null) {
          return;
        }
        var to_write = schedBField.siblings('.sched_b_options');
        if(to_write.length==0) {
          schedBField.parent().append("<div class='sched_b_options'></div>");
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
        $(document).on('click',"a.sched_b_option",function(ev) {
          ev.preventDefault();
          schedBField.val($(this).html());
        });
      }); 
    }
  }

  var validateOfficialValue = function(country_id,uri,hts_field,writeDataFunction) {
    var get_result_box = function() {
      var to_write = hts_field.siblings(".tariff_result");
      if(to_write.length==0) {
        hts_field.parent().append("<div class='tariff_result'></div>");
        to_write = hts_field.siblings(".tariff_result"); 
      }
      return to_write;
    }
    var invalid_callback = function() {
      invalidTariffFields.push(hts_field.attr("id"));
      hts_field.addClass("error");
      var to_write = get_result_box();
      to_write.html("Invalid tariff number.");
      Chain.fireTariffCallbacks('invalid',country_id,hts_field.val());
    }
    var valid_callback = function(data) {
      var schedBField, col, htsNumber;
      hts_field.removeClass("error");
      writeTariffInfo(data);
      if(hts_field.hasClass("hts_field")) {
        col = hts_field.attr("col");
        if(col!=undefined && col.length) {
          //Schedule B in table format
          schedBField = hts_field.parents(".tf_row").find('input.sched_b_field[col="'+col+'"]');
        } else {
          //everything else, just assume 1 schedule b per page
          schedBField = $(".sched_b_field")
        }
        if(schedBField.length) {
          htsNumber = hts_field.val()
          writeScheduleBMatches(htsNumber,country_id,schedBField);
        }
      }
      Chain.fireTariffCallbacks('valid',country_id,hts_field.val());
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
      Chain.fireTariffCallbacks('empty',country_id,'');
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

    validateOfficialValue(hts_field.attr("country"),'/official_tariffs/find_schedule_b?hts='+hts_field.val(),hts_field,wdf);
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
    validateOfficialValue(country_id,'/official_tariffs/find?hts='+hts_field.val()+'&cid='+country_id,hts_field,wdf)
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

  var initScheduleBLinks = function() {
    $(document).on('click', ".lnk_schedb_popup", function(evt) {
      evt.preventDefault();
      scheduleBPopUp($(this).attr("schedb"));
    });
  }

  $(document).ready(function() {
    initScheduleBLinks();
  });

  //Everything in here defines the public API of the Classify object
  return {
    hasInvalidTariffs: function() {
      return invalidTariffFields.length>0;
    },

    enableHtsChecks: function() {
      $(document).on('blur', 'input.sched_b_field', function() {
        validateScheduleBValue($(this))
      });

      $(".sched_b_field").each(function() {
        validateScheduleBValue($(this));
      });

      $(document).on('blur', 'input.hts_field', function() {
        validateHTSValue($(this).attr('country'), $(this));
      });

      $(".hts_field").each(function() {
        validateHTSValue($(this).attr('country'), $(this));
      });
    },

    validateHTS: function(value) {
      return validateHTSFormat(value);
    }
  }

})();