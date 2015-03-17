module OpenChain; module ModelFieldDefinition; module EntryFieldDefinition
  def add_entry_fields
    add_fields CoreModule::ENTRY, [
      [1,:ent_brok_ref,:broker_reference, "Broker Reference",{:data_type=>:string}],
      [2,:ent_entry_num,:entry_number,"Entry Number",{:data_type=>:string}],
      [3,:ent_release_date,:release_date,"Release Date",{:data_type=>:datetime}],
      [4,:ent_comp_num,:company_number,"Broker Company Number",{:data_type=>:string}],
      [5,:ent_div_num,:division_number,"Broker Division Number",{:data_type=>:string}],
      [6,:ent_cust_num,:customer_number,"Customer Number",{:data_type=>:string}],
      [7,:ent_cust_name,:customer_name,"Customer Name",{:data_type=>:string}],
      [8,:ent_type,:entry_type,"Entry Type",{:data_type=>:string}],
      [9,:ent_arrival_date,:arrival_date,"Arrival Date",{:data_type=>:datetime}],
      [10,:ent_filed_date,:entry_filed_date,"Entry Filed Date",{:data_type=>:datetime}],
      [11,:ent_release_date,:release_date,"Release Date",{:data_type=>:datetime}],
      [12,:ent_first_release,:first_release_date,"First Release Date",{:data_type=>:datetime}],
      [14,:ent_last_billed_date,:last_billed_date,"Last Bill Issued Date",{:data_type=>:datetime}],
      [15,:ent_invoice_paid_date,:invoice_paid_date,"Invoice Paid Date",{:data_type=>:datetime}],
      [16,:ent_liq_date,:liquidation_date,"Liquidation Date",{:data_type=>:datetime}],
      [17,:ent_mbols,:master_bills_of_lading,"Master Bills",{:data_type=>:text}],
      [18,:ent_hbols,:house_bills_of_lading,"House Bills",{:data_type=>:text}],
      [19,:ent_sbols,:sub_house_bills_of_lading,"Sub House Bills",{:data_type=>:text}],
      [20,:ent_it_numbers,:it_numbers,"IT Numbers",{:data_type=>:text}],
      [21,:ent_duty_due_date,:duty_due_date,"Duty Due Date",{:data_type=>:date,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [22,:ent_carrier_code,:carrier_code,"Carrier Code",{:data_type=>:string}],
      [23,:ent_total_packages,:total_packages,"Total Packages",{:data_type=>:integer}],
      [24,:ent_total_fees,:total_fees,"Total Fees",{:data_type=>:decimal,:currency=>:usd}],
      [25,:ent_total_duty,:total_duty,"Total Duty",{:data_type=>:decimal,:currency=>:usd}],
      [26,:ent_total_duty_direct,:total_duty_direct,"Total Duty Direct",{:data_type=>:decimal,:currency=>:usd}],
      [27,:ent_entered_value,:entered_value,"Total Entered Value", {:data_type=>:decimal,:currency=>:usd}],
      [28,:ent_customer_references,:customer_references,"Customer References",{:data_type=>:text}],
      [29,:ent_po_numbers,:po_numbers,"PO Numbers",{:data_type=>:text}],
      [30,:ent_mfids,:mfids,"MID Numbers",{:data_type=>:text}],
      [31,:ent_total_invoiced_value,:total_invoiced_value,"Total Commercial Invoice Value",{:data_type=>:decimal,:currency=>:usd}],
      [32,:ent_export_country_codes,:export_country_codes,"Country Export Codes",{:data_type=>:string}],
      [33,:ent_origin_country_codes,:origin_country_codes,"Country Origin Codes",{:data_type=>:string}],
      [34,:ent_vendor_names,:vendor_names,"Vendor Names",{:data_type=>:text}],
      [35,:ent_spis,:special_program_indicators,"SPI(s)",{:data_type=>:string}],
      [36,:ent_export_date,:export_date,"Export Date",{:data_type=>:date}],
      [37,:ent_merch_desc,:merchandise_description,"Merchandise Description",{:data_type=>:string}],
      [38,:ent_transport_mode_code,:transport_mode_code,"Mode of Transport",{:data_type=>:string}],
      [39,:ent_total_units,:total_units,"Total Units",{:data_type=>:decimal}],
      [40,:ent_total_units_uoms,:total_units_uoms,"Total Units UOMs",{:data_type=>:string}],
      [41,:ent_entry_port_code,:entry_port_code,"Port of Entry Code",{:data_type=>:string}],
      [42,:ent_ult_con_code,:ult_consignee_code,"Ult Consignee Code",{:data_type=>:string}],
      [43,:ent_ult_con_name,:ult_consignee_name,"Ult Consignee Name",{:data_type=>:string}],
      [44,:ent_gross_weight,:gross_weight,"Gross Weight",{:data_type=>:integer}],
      [45,:ent_total_packages_uom,:total_packages_uom,"Total Packages UOM",{:data_type=>:string}],
      [46,:ent_cotton_fee,:cotton_fee,"Cotton Fee",{:data_type=>:decimal,:currency=>:usd}],
      [47,:ent_hmf,:hmf,"HMF",{:data_type=>:decimal,:currency=>:usd}],
      [48,:ent_mpf,:mpf,"MPF",{:data_type=>:decimal,:currency=>:usd}],
      [49,:ent_container_nums,:container_numbers,"Container Numbers",{:data_type=>:string}],
      [50,:ent_container_sizes,:container_sizes,"Container Sizes",{:data_type=>:string}],
      [51,:ent_fcl_lcl,:fcl_lcl,"FCL/LCL",{:data_type=>:string}],
      [52,:ent_lading_port_code,:lading_port_code,"Port of Lading Code",{:data_type=>:string}],
      [53,:ent_unlading_port_code,:unlading_port_code,"Port of Unlading Code",{:data_type=>:string}],
      [54,:ent_consignee_address_1,:consignee_address_1,"Ult Consignee Address 1",{:data_type=>:string}],
      [55,:ent_consignee_address_2,:consignee_address_2,"Ult Consignee Address 2",{:data_type=>:string}],
      [56,:ent_consignee_city,:consignee_city,"Ult Consignee City",{:data_type=>:string}],
      [57,:ent_consignee_state,:consignee_state,"Ult Consignee State",{:data_type=>:string}],
      [58,:ent_lading_port_name,:name,"Port of Lading Name",{:data_type=>:string,
        :import_lambda => lambda { |ent, data|
          port = Port.find_by_name data
          return "Port with name \"#{data}\" could not be found." unless port
          ent.lading_port_code = port.schedule_k_code
          "Lading Port set to #{port.name}"
        },
        :export_lambda => lambda {|ent|
          ent.lading_port.blank? ? "" : ent.lading_port.name
        },
        :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_k_code = entries.lading_port_code)"
      }],
      [59,:ent_unlading_port_name,:name,"Port of Unlading Name",{:data_type=>:string,
        :import_lambda => lambda { |ent, data|
          port = Port.find_by_name data
          return "Port with name \"#{data}\" could not be found." unless port
          ent.unlading_port_code = port.schedule_d_code
          "Unlading Port set to #{port.name}"
        },
        :export_lambda => lambda {|ent|
          ent.unlading_port.blank? ? "" : ent.unlading_port.name
        },
        :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_d_code = entries.unlading_port_code)"
      }],
      [60,:ent_entry_port_name,:name,"Port of Entry Name",{:data_type=>:string,
        :import_lambda => lambda { |ent, data|
          port = Port.find_by_name data
          return "Port with name \"#{data}\" could not be found." unless port
          ent.entry_port_code = (ent.source_system == "Fenix" ? port.cbsa_port : port.schedule_d_code)
          "Entry Port set to #{port.name}"
        },
        :export_lambda => lambda {|ent|
          ent.entry_port.blank? ? "" : ent.entry_port.name
        },
        qualified_field_name: "(CASE entries.source_system WHEN 'Fenix' THEN (SELECT name FROM ports WHERE ports.cbsa_port = entries.entry_port_code) ELSE (SELECT name FROM ports WHERE ports.schedule_d_code = entries.entry_port_code) END)"
      }],
      [61,:ent_vessel,:vessel,"Vessel/Airline",{:data_type=>:string}],
      [62,:ent_voyage,:voyage,"Voyage/Flight",{:data_type=>:string}],
      [63,:ent_file_logged_date,:file_logged_date,"File Logged Date",{:data_type=>:datetime}],
      [64,:ent_last_exported_from_source,:last_exported_from_source,"System Extract Date",{:data_type=>:datetime}],
      [65,:ent_importer_tax_id,:importer_tax_id,"Importer Tax ID",{:data_type=>:string}],
      [66,:ent_cargo_control_number,:cargo_control_number,"Cargo Control Number",{:data_type=>:string}],
      [67,:ent_ship_terms,:ship_terms,"Ship Terms (CA)",{:data_type=>:string}],
      [68,:ent_direct_shipment_date,:direct_shipment_date,"Direct Shipment Date",{:data_type=>:date}],
      [69,:ent_across_sent_date,:across_sent_date,"ACROSS Sent Date",{:data_type=>:datetime}],
      [70,:ent_pars_ack_date,:pars_ack_date,"PARS ACK Date",{:data_type=>:datetime}],
      [71,:ent_pars_reject_date,:pars_reject_date,"PARS Reject Date",{:data_type=>:datetime}],
      [72,:ent_cadex_accept_date,:cadex_accept_date,"CADEX Accept Date",{:data_type=>:datetime}],
      [73,:ent_cadex_sent_date,:cadex_sent_date,"CADEX Sent Date",{:data_type=>:datetime}],
      [74,:ent_us_exit_port_code,:us_exit_port_code,"US Exit Port Code",{:data_type=>:string}],
      [75,:ent_origin_state_code,:origin_state_codes,"Origin State Codes",{:data_type=>:string}],
      [76,:ent_export_state_code,:export_state_codes,"Export State Codes",{:data_type=>:string}],
      [77,:ent_recon_flags,:recon_flags,"Recon Flags",{:data_type=>:string}],
      [78,:ent_ca_entry_type,:entry_type,"Entry Type (CA)",{:data_type=>:string}],
      [79, :ent_broker_invoice_total, :broker_invoice_total, "Total Broker Invoice", {:data_type=>:decimal, :currency=>:usd, :can_view_lambda=>lambda {|u| u.view_broker_invoices?}}],
      [80,:ent_release_cert_message,:release_cert_message, "Release Certification Message", {:data_type=>:string}],
      [81,:ent_fda_message,:fda_message,"FDA Message",{:data_type=>:string}],
      [82,:ent_fda_transmit_date,:fda_transmit_date,"FDA Transmit Date",{:data_type=>:datetime}],
      [83,:ent_fda_review_date,:fda_review_date,"FDA Review Date",{:data_type=>:datetime}],
      [84,:ent_fda_release_date,:fda_release_date,"FDA Release Date",{:data_type=>:datetime}],
      [85,:ent_charge_codes,:charge_codes,"Charge Codes Used",{:data_type=>:string, :can_view_lambda=>lambda {|u| u.view_broker_invoices?}}],
      [86,:ent_isf_sent_date,:isf_sent_date,"ISF Sent Date",{:data_type=>:datetime}],
      [87,:ent_isf_accepted_date,:isf_accepted_date,"ISF Accepted Date",{:data_type=>:datetime}],
      [88,:ent_docs_received_date,:docs_received_date,"Docs Received Date",{:data_type=>:date}],
      [89,:ent_trucker_called_date,:trucker_called_date,"Trucker Called Date",{:data_type=>:datetime}],
      [90,:ent_free_date,:free_date,"Free Date",{:data_type=>:date}],
      [91,:ent_edi_received_date,:edi_received_date,"EDI Received Date",{:data_type=>:date}],
      [92,:ent_ci_line_count,:ci_line_count, "Commercial Invoice Line Count",{
        :import_lambda=>lambda {|obj,data| "Commercial Invoice Line Count ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.commercial_invoice_lines.count},
        :qualified_field_name=>"(select count(*) from commercial_invoice_lines cil inner join commercial_invoices ci on ci.id = cil.commercial_invoice_id where ci.entry_id = entries.id)",
        :data_type=>:integer
        }
      ],
      [93,:ent_total_gst,:total_gst,"Total GST",{:data_type=>:decimal}],
      [94,:ent_total_duty_gst,:total_duty_gst,"Total Duty & GST",{:data_type=>:decimal}],
      [95,:ent_first_entry_sent_date,:first_entry_sent_date,"First Summary Sent Date",{:data_type=>:datetime,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [96,:ent_paperless_release,:paperless_release,"Paperless Entry Summary",{:data_type=>:boolean}],
      [97,:ent_census_warning,:census_warning,"Census Warning",{:data_type=>:boolean,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [98,:ent_error_free_release,:error_free_release,"Error Free Release",{:data_type=>:boolean,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [99,:ent_paperless_certification,:paperless_certification,"Paperless Release Cert",{:data_type=>:boolean}],
      [100,:ent_pdf_count,:pdf_count,"PDF Attachment Count", {
        :import_lambda=>lambda {|obj,data| "PDF Attachment Count ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.attachments.where("attached_content_type = 'application/pdf' OR lower(attached_file_name) LIKE '%pdf'").count},
        :qualified_field_name=>"(select count(*) from attachments where attachable_type = \"Entry\" and attachable_id = entries.id and (attached_content_type=\"application/pdf\"OR lower(attached_file_name) LIKE '%pdf'))",
        :data_type=>:integer,
        :can_view_lambda=> lambda {|u| u.company.broker?}
      }],
      [101,:ent_destination_state,:destination_state,"Destination State",{:data_type=>:string}],
      [102,:ent_liquidation_duty,:liquidation_duty,"Liquidated - Duty",{:data_type=>:decimal}],
      [103,:ent_liquidation_fees,:liquidation_fees,"Liquidated - Fees",{:data_type=>:decimal}],
      [104,:ent_liquidation_tax,:liquidation_tax,"Liquidated - Tax",{:data_type=>:decimal}],
      [105,:ent_liquidation_ada,:liquidation_ada,"Liquidated - ADA",{:data_type=>:decimal}],
      [106,:ent_liquidation_cvd,:liquidation_cvd,"Liquidated - CVD",{:data_type=>:decimal}],
      [107,:ent_liquidation_total,:liquidation_total,"Liquidated - Total",{:data_type=>:decimal}],
      [108,:ent_liquidation_extension_count,:liquidation_extension_count,"Liquidated - # of Extensions",{:data_type=>:integer}],
      [109,:ent_liquidation_extension_description,:liquidation_extension_description,"Liquidated - Extension",{:data_type=>:string}],
      [110,:ent_liquidation_extension_code,:liquidation_extension_code,"Liquidated - Extension Code",{:data_type=>:string}],
      [111,:ent_liquidation_action_description,:liquidation_action_description,"Liquidated - Action",{:data_type=>:string}],
      [112,:ent_liquidation_action_code,:liquidation_action_code,"Liquidated - Action Code",{:data_type=>:string}],
      [113,:ent_liquidation_type,:liquidation_type,"Liquidated - Type",{:data_type=>:string}],
      [114,:ent_liquidation_type_code,:liquidation_type_code,"Liquidated - Type Code",{:data_type=>:string}],
      [115,:ent_daily_statement_number,:daily_statement_number,"Daily Statement Number",{:data_type=>:string}],
      [116,:ent_daily_statement_due_date,:daily_statement_due_date,"Daily Statement Due",{:data_type=>:date}],
      [117,:ent_daily_statement_approved_date,:daily_statement_approved_date,"Daily Statement Approved Date",{:data_type=>:date}],
      [118,:ent_monthly_statement_number,:monthly_statement_number,"PMS #",{:data_type=>:string}],
      [119,:ent_monthly_statement_due_date,:monthly_statement_due_date,"PMS Due Date",{:data_type=>:date}],
      [120,:ent_monthly_statement_received_date,:monthly_statement_received_date,"PMS Received Date",{:data_type=>:date}],
      [121,:ent_monthly_statement_paid_date,:monthly_statement_paid_date,"PMS Paid Date",{:data_type=>:date}],
      [122,:ent_pay_type,:pay_type,"Pay Type",{:data_type=>:integer}],
      [123,:ent_statement_month,:statement_month,"PMS Month",{
        :import_lambda=>lambda {|obj,data| "PMS Month ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.monthly_statement_due_date ? obj.monthly_statement_due_date.month : nil},
        :qualified_field_name=>"month(monthly_statement_due_date)",
        :data_type=>:integer
      }],
      [124,:ent_first_7501_print,:first_7501_print,"7501 Print Date - First",{:data_type=>:datetime,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [125,:ent_last_7501_print,:last_7501_print,"7501 Print Date - Last",{:data_type=>:datetime,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [126,:ent_duty_billed,:duty_billed,"Total Duty Billed",{
        :import_lambda=>lambda {|obj,data| "Total Duty Billed ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.broker_invoice_lines.where(:charge_code=>'0001').sum(:charge_amount)},
        :qualified_field_name=>"(select sum(charge_amount) from broker_invoice_lines inner join broker_invoices on broker_invoices.id = broker_invoice_lines.broker_invoice_id where broker_invoices.entry_id = entries.id and charge_code = '0001')",
        :data_type=>:decimal,
        :can_view_lambda=>lambda {|u| u.view_broker_invoices? && u.company.broker?}
      }],
      [127,:ent_first_it_date,:first_it_date,"First IT Date",{:data_type=>:date}],
      [128,:ent_first_do_issued_date,:first_do_issued_date,"First DO Date",{:data_type=>:datetime}],
      [129,:ent_part_numbers,:part_numbers,"Part Numbers",{:data_type=>:text}],
      [130,:ent_commercial_invoice_numbers,:commercial_invoice_numbers,"Commercial Invoice Numbers",{:data_type=>:text}],
      [131,:ent_eta_date,:eta_date,"ETA Date",{:data_type=>:date}],
      [132,:ent_delivery_order_pickup_date,:delivery_order_pickup_date,"Delivery Order Pickup Date",{:data_type=>:datetime}],
      [133,:ent_freight_pickup_date,:freight_pickup_date,"Freight Pickup Date",{:data_type=>:datetime}],
      [134,:ent_k84_receive_date, :k84_receive_date, "K84 Received Date", {:data_type=>:date}],
      [135,:ent_k84_month, :k84_month, "K84 Month", {:data_type=>:integer}],
      [136,:ent_k84_due_date, :k84_due_date, "K84 Due Date", {:data_type=>:date}],
      [137,:ent_rule_state,:rule_state,"Business Rule State",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules_state },
        :qualified_field_name=> "(select state
          from business_validation_results bvr
          where bvr.validatable_type = 'Entry' and bvr.validatable_id = entries.id
          order by (
          case bvr.state
              when 'Fail' then 0
              when 'Review' then 1
              when 'Pass' then 2
              when 'Skipped' then 3
              else 4
          end
          )
          limit 1)",
        :can_view_lambda=>lambda {|u| u.company.master?}
      }],
      [138,:ent_carrier_name,:carrier_name,"Carrier Name", {:data_type=>:string}],
      [139,:ent_exam_ordered_date,:exam_ordered_date,"Exam Ordered Date",{:data_type=>:datetime}],
      [140,:ent_employee_name,:employee_name,"Employee",{:data_type=>:string,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [141,:ent_location_of_goods,:location_of_goods,"Location Of Goods", {:data_type=>:string}],
      [142,:ent_final_statement_date,:final_statement_date,"Final Statement Date", {:data_type=>:date}],
      [143,:ent_bond_type,:bond_type,"Bond Type", {:data_type=>:string}],
      [146,:ent_worksheeet_date,:worksheet_date,"Worksheet Date",{:data_type=>:date}],
      [147,:ent_available_date,:available_date,"Available Date",{:data_type=>:date}],
      [148,:ent_departments, :departments, "Departments", {:data_type=>:text}],
      [149,:ent_total_add, :total_add, "Total ADD", {:data_type=>:decimal,:currency=>:usd}],
      [150,:ent_total_cvd, :total_cvd, "Total CVD", {:data_type=>:decimal,:currency=>:usd}],
      [151,:ent_attachment_types,:attachment_types,"Attachment Types",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Attachment Types ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.attachment_types.join("\n ") },
        :qualified_field_name=> "(SELECT GROUP_CONCAT(DISTINCT a_types.attachment_type ORDER BY a_types.attachment_type SEPARATOR '\n ')
          FROM attachments a_types
          WHERE a_types.attachable_id = entries.id AND a_types.attachable_type = 'Entry' AND LENGTH(RTRIM(IFNULL(a_types.attachment_type, ''))) > 0)",
        :can_view_lambda=>lambda {|u| u.company.master?}
      }],
      [152,:ent_b3_print_date, :b3_print_date, "B3 Print Date", {:data_type=>:datetime}],
      [153,:ent_failed_business_rules,:failed_business_rules,"Failed Business Rule Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Failed Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.failed_business_rules.join("\n ") },
        :qualified_field_name=> "(SELECT GROUP_CONCAT(failed_rule.name ORDER BY failed_rule.name SEPARATOR '\n ')
          FROM business_validation_results failed_bvr
          INNER JOIN business_validation_rules failed_rule ON failed_rule.business_validation_template_id = failed_bvr.business_validation_template_id
          INNER JOIN business_validation_rule_results failed_bvrr ON failed_bvr.id = failed_bvrr.business_validation_result_id AND failed_bvrr.business_validation_rule_id = failed_rule.id AND failed_bvrr.state = 'Fail'
          WHERE failed_bvr.validatable_id = entries.id AND failed_bvr.validatable_type = 'Entry'
          GROUP BY failed_bvr.validatable_id)",
        :can_view_lambda=>lambda {|u| u.company.master?}
      }],
      [154, :ent_store_names, :store_names, "Store Names", {:data_type=>:text}],
      [155, :ent_final_delivery_date, :final_delivery_date, "Final Delivery Date", {:data_type=>:datetime}],
      [156, :ent_expected_update_time, :expected_update_time, "Expected Update Time", {:data_type=>:datetime, :can_view_lambda=>lambda {|u| u.company.broker?}}]
    ]
    add_fields CoreModule::ENTRY, make_country_arrays(500,'ent',"entries","import_country")
    add_fields CoreModule::ENTRY, make_sync_record_arrays(600,'ent','entries','Entry')
  end
end; end; end
