module OpenChain; module ModelFieldDefinition; module EntryFieldDefinition
  def add_entry_fields
    add_fields CoreModule::ENTRY, [
      [1, :ent_brok_ref, :broker_reference, "Broker Reference", {:data_type=>:string}],
      [2, :ent_entry_num, :entry_number, "Entry Number", {:data_type=>:string}],
      [3, :ent_release_date, :release_date, "Release Date", {:data_type=>:datetime}],
      [4, :ent_comp_num, :company_number, "Broker Company Number", {:data_type=>:string}],
      [5, :ent_div_num, :division_number, "Broker Division Number", {:data_type=>:string}],
      [6, :ent_cust_num, :customer_number, "Customer Number", {:data_type=>:string}],
      [7, :ent_cust_name, :customer_name, "Customer Name", {:data_type=>:string}],
      [8, :ent_type, :entry_type, "Entry Type", {:data_type=>:string}],
      [9, :ent_arrival_date, :arrival_date, "Arrival Date", {:data_type=>:datetime}],
      [10, :ent_filed_date, :entry_filed_date, "Entry Filed Date", {:data_type=>:datetime}],
      [12, :ent_first_release, :first_release_date, "First Release Date", {:data_type=>:datetime}],
      # last billed date comes from kewill, so it's written to the DB, we're deriving first billed date so it's a calculation
      [13, :ent_first_billed_date, :first_billed_date, "First Bill Issued Date", {
        data_type: :date,
        read_only: true,
        export_lambda: lambda {|ent| ent.broker_invoices.collect {|bi| bi.invoice_date}.compact.min},
        qualified_field_name: "(SELECT min(bi.invoice_date) FROM broker_invoices bi WHERE bi.entry_id = entries.id)"
      }],
      [14, :ent_last_billed_date, :last_billed_date, "Last Bill Issued Date", {:data_type=>:datetime}],
      [15, :ent_invoice_paid_date, :invoice_paid_date, "Invoice Paid Date", {:data_type=>:datetime}],
      [16, :ent_liq_date, :liquidation_date, "Liquidation Date", {:data_type=>:datetime}],
      [17, :ent_mbols, :master_bills_of_lading, "Master Bills", {:data_type=>:text}],
      [18, :ent_hbols, :house_bills_of_lading, "House Bills", {:data_type=>:text}],
      [19, :ent_sbols, :sub_house_bills_of_lading, "Sub House Bills", {:data_type=>:text}],
      [20, :ent_it_numbers, :it_numbers, "IT Numbers", {:data_type=>:text}],
      [21, :ent_duty_due_date, :duty_due_date, "Duty Due Date", {:data_type=>:date}],
      [22, :ent_carrier_code, :carrier_code, "Carrier Code", {:data_type=>:string}],
      [23, :ent_total_packages, :total_packages, "Total Packages", {:data_type=>:integer}],
      [24, :ent_total_fees, :total_fees, "Total Fees", {:data_type=>:decimal, :currency=>:usd}],
      [25, :ent_total_duty, :total_duty, "Total Duty", {:data_type=>:decimal, :currency=>:usd}],
      [26, :ent_total_duty_direct, :total_duty_direct, "Total Duty Direct", {:data_type=>:decimal, :currency=>:usd}],
      [27, :ent_entered_value, :entered_value, "Total Entered Value", {:data_type=>:decimal, :currency=>:usd}],
      [28, :ent_customer_references, :customer_references, "Customer References", {:data_type=>:text}],
      [29, :ent_po_numbers, :po_numbers, "PO Numbers", {:data_type=>:text}],
      [30, :ent_mfids, :mfids, "MID Numbers", {:data_type=>:text}],
      [31, :ent_total_invoiced_value, :total_invoiced_value, "Total Commercial Invoice Value", {:data_type=>:decimal, :currency=>:usd}],
      [32, :ent_export_country_codes, :export_country_codes, "Country Export Codes", {:data_type=>:string}],
      [33, :ent_origin_country_codes, :origin_country_codes, "Country Origin Codes", {:data_type=>:string}],
      [34, :ent_vendor_names, :vendor_names, "Vendor Names", {:data_type=>:text}],
      [35, :ent_spis, :special_program_indicators, "SPI(s)", {:data_type=>:string}],
      [36, :ent_export_date, :export_date, "Export Date", {:data_type=>:date}],
      [37, :ent_merch_desc, :merchandise_description, "Merchandise Description", {:data_type=>:string}],
      [38, :ent_transport_mode_code, :transport_mode_code, "Mode of Transport", {:data_type=>:string}],
      [39, :ent_total_units, :total_units, "Total Units", {:data_type=>:decimal}],
      [40, :ent_total_units_uoms, :total_units_uoms, "Total Units UOMs", {:data_type=>:string}],
      [41, :ent_entry_port_code, :entry_port_code, "Port of Entry Code", {:data_type=>:string}],
      [42, :ent_ult_con_code, :ult_consignee_code, "Ult Consignee Code", {:data_type=>:string}],
      [43, :ent_ult_con_name, :ult_consignee_name, "Ult Consignee Name", {:data_type=>:string}],
      [44, :ent_gross_weight, :gross_weight, "Gross Weight", {:data_type=>:integer}],
      [45, :ent_total_packages_uom, :total_packages_uom, "Total Packages UOM", {:data_type=>:string}],
      [46, :ent_cotton_fee, :cotton_fee, "Cotton Fee", {:data_type=>:decimal, :currency=>:usd}],
      [47, :ent_hmf, :hmf, "HMF", {:data_type=>:decimal, :currency=>:usd}],
      [48, :ent_mpf, :mpf, "MPF", {:data_type=>:decimal, :currency=>:usd}],
      [49, :ent_container_nums, :container_numbers, "Container Numbers", {:data_type=>:string}],
      [50, :ent_container_sizes, :container_sizes, "Container Sizes", {:data_type=>:string}],
      [51, :ent_fcl_lcl, :fcl_lcl, "FCL/LCL", {:data_type=>:string}],
      [52, :ent_lading_port_code, :lading_port_code, "Port of Lading Code", {:data_type=>:string}],
      [53, :ent_unlading_port_code, :unlading_port_code, "Port of Unlading Code", {:data_type=>:string}],
      [54, :ent_consignee_address_1, :consignee_address_1, "Ult Consignee Address 1", {:data_type=>:string}],
      [55, :ent_consignee_address_2, :consignee_address_2, "Ult Consignee Address 2", {:data_type=>:string}],
      [56, :ent_consignee_city, :consignee_city, "Ult Consignee City", {:data_type=>:string}],
      [57, :ent_consignee_state, :consignee_state, "Ult Consignee State", {:data_type=>:string}],
      [58, :ent_lading_port_name, :name, "Port of Lading Name", {:data_type=>:string,
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
      [59, :ent_unlading_port_name, :name, "Port of Unlading Name", {:data_type=>:string,
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
      [60, :ent_entry_port_name, :name, "Port of Entry Name", {:data_type=>:string,
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
      [61, :ent_vessel, :vessel, "Vessel/Airline", {:data_type=>:string}],
      [62, :ent_voyage, :voyage, "Voyage/Flight", {:data_type=>:string}],
      [63, :ent_file_logged_date, :file_logged_date, "File Logged Date", {:data_type=>:datetime}],
      [64, :ent_last_exported_from_source, :last_exported_from_source, "System Extract Date", {:data_type=>:datetime}],
      [65, :ent_importer_tax_id, :importer_tax_id, "Importer Tax ID", {:data_type=>:string}],
      [66, :ent_cargo_control_number, :cargo_control_number, "Cargo Control Number", {:data_type=>:string}],
      [67, :ent_ship_terms, :ship_terms, "Ship Terms (CA)", {:data_type=>:string}],
      [68, :ent_direct_shipment_date, :direct_shipment_date, "Direct Shipment Date", {:data_type=>:date}],
      [69, :ent_across_sent_date, :across_sent_date, "ACROSS Sent Date", {:data_type=>:datetime}],
      [70, :ent_pars_ack_date, :pars_ack_date, "PARS ACK Date", {:data_type=>:datetime}],
      [71, :ent_pars_reject_date, :pars_reject_date, "PARS Reject Date", {:data_type=>:datetime}],
      [72, :ent_cadex_accept_date, :cadex_accept_date, "CADEX Accept Date", {:data_type=>:datetime}],
      [73, :ent_cadex_sent_date, :cadex_sent_date, "CADEX Sent Date", {:data_type=>:datetime}],
      [74, :ent_us_exit_port_code, :us_exit_port_code, "US Exit Port Code", {:data_type=>:string}],
      [75, :ent_origin_state_code, :origin_state_codes, "Origin State Codes", {:data_type=>:string}],
      [76, :ent_export_state_code, :export_state_codes, "Export State Codes", {:data_type=>:string}],
      [77, :ent_recon_flags, :recon_flags, "Recon Flags", {:data_type=>:string}],
      [78, :ent_ca_entry_type, :entry_type, "Entry Type (CA)", {:data_type=>:string}],
      [79, :ent_broker_invoice_total, :broker_invoice_total, "Total Broker Invoice", {:data_type=>:decimal, :currency=>:usd, :can_view_lambda=>lambda {|u| u.view_broker_invoices?}}],
      [80, :ent_release_cert_message, :release_cert_message, "Release Certification Message", {:data_type=>:string}],
      [81, :ent_fda_message, :fda_message, "FDA Message", {:data_type=>:string}],
      [82, :ent_fda_transmit_date, :fda_transmit_date, "FDA Transmit Date", {:data_type=>:datetime}],
      [83, :ent_fda_review_date, :fda_review_date, "FDA Review Date", {:data_type=>:datetime}],
      [84, :ent_fda_release_date, :fda_release_date, "FDA Release Date", {:data_type=>:datetime}],
      [85, :ent_charge_codes, :charge_codes, "Charge Codes Used", {:data_type=>:string, :can_view_lambda=>lambda {|u| u.view_broker_invoices?}}],
      [86, :ent_isf_sent_date, :isf_sent_date, "ISF Sent Date", {:data_type=>:datetime}],
      [87, :ent_isf_accepted_date, :isf_accepted_date, "ISF Accepted Date", {:data_type=>:datetime}],
      [88, :ent_docs_received_date, :docs_received_date, "Docs Received Date", {:data_type=>:date}],
      [89, :ent_trucker_called_date, :trucker_called_date, "Trucker Called Date", {:data_type=>:datetime}],
      [90, :ent_free_date, :free_date, "Free Date", {:data_type=>:date}],
      [91, :ent_edi_received_date, :edi_received_date, "EDI Received Date", {:data_type=>:date}],
      [92, :ent_ci_line_count, :ci_line_count, "Commercial Invoice Line Count", {
        :import_lambda=>lambda {|obj, data| "Commercial Invoice Line Count ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.commercial_invoice_lines.count},
        :qualified_field_name=>"(select count(*) from commercial_invoice_lines cil inner join commercial_invoices ci on ci.id = cil.commercial_invoice_id where ci.entry_id = entries.id)",
        :data_type=>:integer
        }
      ],
      [93, :ent_total_gst, :total_gst, "Total GST", {:data_type=>:decimal}],
      [94, :ent_total_duty_gst, :total_duty_gst, "Total Duty & GST", {:data_type=>:decimal}],
      [95, :ent_first_entry_sent_date, :first_entry_sent_date, "First Summary Sent Date", {:data_type=>:datetime}],
      [96, :ent_paperless_release, :paperless_release, "Paperless Entry Summary", {:data_type=>:boolean}],
      [97, :ent_census_warning, :census_warning, "Census Warning", {:data_type=>:boolean, :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [98, :ent_error_free_release, :error_free_release, "Error Free Release", {:data_type=>:boolean, :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [99, :ent_paperless_certification, :paperless_certification, "Paperless Release Cert", {:data_type=>:boolean}],
      [100, :ent_pdf_count, :pdf_count, "PDF Attachment Count", {
        :import_lambda=>lambda {|obj, data| "PDF Attachment Count ignored. (read only)"},
          :export_lambda=>lambda {|obj| obj.attachments.where("attached_content_type = 'application/pdf' OR lower(attached_file_name) LIKE '%pdf'").count},
        :qualified_field_name=>"(select count(*) from attachments where attachable_type = \"Entry\" and attachable_id = entries.id and (attached_content_type=\"application/pdf\"OR lower(attached_file_name) LIKE '%pdf'))",
        :data_type=>:integer,
        :can_view_lambda=> lambda {|u| u.company.broker?}
      }],
      [101, :ent_destination_state, :destination_state, "Destination State", {:data_type=>:string}],
      [102, :ent_liquidation_duty, :liquidation_duty, "Liquidated - Duty", {:data_type=>:decimal}],
      [103, :ent_liquidation_fees, :liquidation_fees, "Liquidated - Fees", {:data_type=>:decimal}],
      [104, :ent_liquidation_tax, :liquidation_tax, "Liquidated - Tax", {:data_type=>:decimal}],
      [105, :ent_liquidation_ada, :liquidation_ada, "Liquidated - ADA", {:data_type=>:decimal}],
      [106, :ent_liquidation_cvd, :liquidation_cvd, "Liquidated - CVD", {:data_type=>:decimal}],
      [107, :ent_liquidation_total, :liquidation_total, "Liquidated - Total", {:data_type=>:decimal}],
      [108, :ent_liquidation_extension_count, :liquidation_extension_count, "Liquidated - # of Extensions", {:data_type=>:integer}],
      [109, :ent_liquidation_extension_description, :liquidation_extension_description, "Liquidated - Extension", {:data_type=>:string}],
      [110, :ent_liquidation_extension_code, :liquidation_extension_code, "Liquidated - Extension Code", {:data_type=>:string}],
      [111, :ent_liquidation_action_description, :liquidation_action_description, "Liquidated - Action", {:data_type=>:string}],
      [112, :ent_liquidation_action_code, :liquidation_action_code, "Liquidated - Action Code", {:data_type=>:string}],
      [113, :ent_liquidation_type, :liquidation_type, "Liquidated - Type", {:data_type=>:string}],
      [114, :ent_liquidation_type_code, :liquidation_type_code, "Liquidated - Type Code", {:data_type=>:string}],
      [115, :ent_daily_statement_number, :daily_statement_number, "Daily Statement Number", {:data_type=>:string}],
      [116, :ent_daily_statement_due_date, :daily_statement_due_date, "Daily Statement Due", {:data_type=>:date}],
      [117, :ent_daily_statement_approved_date, :daily_statement_approved_date, "Daily Statement Approved Date", {:data_type=>:date}],
      [118, :ent_monthly_statement_number, :monthly_statement_number, "PMS #", {:data_type=>:string}],
      [119, :ent_monthly_statement_due_date, :monthly_statement_due_date, "PMS Due Date", {:data_type=>:date}],
      [120, :ent_monthly_statement_received_date, :monthly_statement_received_date, "PMS Received Date", {:data_type=>:date}],
      [121, :ent_monthly_statement_paid_date, :monthly_statement_paid_date, "PMS Paid Date", {:data_type=>:date}],
      [122, :ent_pay_type, :pay_type, "Pay Type", {:data_type=>:integer}],
      [123, :ent_statement_month, :statement_month, "PMS Month", {
        :import_lambda=>lambda {|obj, data| "PMS Month ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.monthly_statement_due_date ? obj.monthly_statement_due_date.month : nil},
        :qualified_field_name=>"month(monthly_statement_due_date)",
        :data_type=>:integer
      }],
      [124, :ent_first_7501_print, :first_7501_print, "7501 Print Date - First", {:data_type=>:datetime, :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [125, :ent_last_7501_print, :last_7501_print, "7501 Print Date - Last", {:data_type=>:datetime, :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [126, :ent_duty_billed, :duty_billed, "Total Duty Billed", {
        :import_lambda=>lambda {|obj, data| "Total Duty Billed ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.total_billed_duty_amount },
        :qualified_field_name=>Entry.total_duty_billed_subquery,
        :data_type=>:decimal,
        :can_view_lambda=>lambda {|u| u.view_broker_invoices? && u.company.broker?}
      }],
      [127, :ent_first_it_date, :first_it_date, "First IT Date", {:data_type=>:date}],
      [128, :ent_first_do_issued_date, :first_do_issued_date, "First DO Date", {:data_type=>:datetime}],
      [129, :ent_part_numbers, :part_numbers, "Part Numbers", {:data_type=>:text}],
      [130, :ent_commercial_invoice_numbers, :commercial_invoice_numbers, "Commercial Invoice Numbers", {:data_type=>:text}],
      [131, :ent_eta_date, :eta_date, "ETA Date", {:data_type=>:date}],
      [132, :ent_delivery_order_pickup_date, :delivery_order_pickup_date, "Delivery Order Pickup Date", {:data_type=>:datetime}],
      [133, :ent_freight_pickup_date, :freight_pickup_date, "Freight Pickup Date", {:data_type=>:datetime}],
      [134, :ent_k84_receive_date, :k84_receive_date, "K84 Received Date", {:data_type=>:date}],
      [135, :ent_k84_month, :k84_month, "K84 Month", {:data_type=>:integer}],
      [136, :ent_k84_due_date, :k84_due_date, "K84 Due Date", {:data_type=>:date}],
      # used to be ent_rule_sate
      [138, :ent_carrier_name, :carrier_name, "Carrier Name", {:data_type=>:string}],
      [139, :ent_exam_ordered_date, :exam_ordered_date, "CBSA Exam Ordered Date", {:data_type=>:datetime}],
      [140, :ent_employee_name, :employee_name, "Employee", {:data_type=>:string, :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [141, :ent_location_of_goods, :location_of_goods, "Location Of Goods", {:data_type=>:string}],
      [142, :ent_final_statement_date, :final_statement_date, "Final Statement Date", {:data_type=>:date}],
      [143, :ent_bond_type, :bond_type, "Bond Type", {:data_type=>:string}],
      [146, :ent_worksheeet_date, :worksheet_date, "Worksheet Date", {:data_type=>:date}],
      [147, :ent_available_date, :available_date, "Available Date", {:data_type=>:date}],
      [148, :ent_departments, :departments, "Departments", {:data_type=>:text}],
      [149, :ent_total_add, :total_add, "Total ADD", {:data_type=>:decimal, :currency=>:usd}],
      [150, :ent_total_cvd, :total_cvd, "Total CVD", {:data_type=>:decimal, :currency=>:usd}],
      [152, :ent_b3_print_date, :b3_print_date, "B3 Print Date", {:data_type=>:datetime}],
      # used to be ent_failed_business_rules
      [154, :ent_store_names, :store_names, "Store Names", {:data_type=>:text}],
      [155, :ent_final_delivery_date, :final_delivery_date, "Final Delivery Date", {:data_type=>:datetime}],
      [156, :ent_expected_update_time, :expected_update_time, "Expected Update Time", {:data_type=>:datetime, :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [157, :ent_fda_pending_release_line_count, :fda_pending_release_line_count, "FDA Pending Release Line Count", {data_type: :integer}],
      [158, :ent_house_carrier_code, :house_carrier_code, "House Carrier Code"],
      [159, :ent_currencies, :currencies, "Currencies", {
        :import_lambda=>lambda {|obj, data| "Currencies ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.commercial_invoices.map {|ci| ci.currency}.uniq.join("\n")},
        :qualified_field_name=> '(SELECT GROUP_CONCAT(DISTINCT currency SEPARATOR "\n") FROM commercial_invoices AS ci where ci.entry_id = entries.id)',
        :data_type=>:string
      }],
      [160, :ent_location_of_goods_desc, :location_of_goods_description, "Location of Goods Description", {data_type: :string}],
      [161, :ent_bol_received_date, :bol_received_date, "BOL Date", {:data_type=>:datetime}],
      [162, :ent_user_notes, :user_notes, "User Notes", {
        :data_type=>:string,
        :read_only=>true,
        :import_lambda=>lambda {|obj, data| "User Notes ignored. (read only)"},
        :export_lambda=>lambda { |obj|
          user_comments = obj.entry_comments.select {|ec| ec.comment_type=='USER'}
          user_comment_strings = user_comments.map do |uc|
            time_stamp = uc.generated_at ? "#{uc.generated_at.in_time_zone(Time.zone)} - " : ""
            "#{uc.body} (#{time_stamp}#{uc.username})"
          end
          user_comment_strings.join("\n")
        },
        :qualified_field_name=>lambda {"(SELECT GROUP_CONCAT(IF(ec.generated_at IS NOT NULL, CONCAT(ec.body, ' (', DATE_FORMAT(CONVERT_TZ(ec.generated_at, 'UTC', '#{Time.zone.tzinfo.name}'),'%Y-%m-%d %H:%i'), ' - ', ec.username, ')'), CONCAT(ec.body, ' (', ec.username, ')')) SEPARATOR '\n') FROM entry_comments ec INNER JOIN entries e ON e.id = ec.entry_id WHERE e.id = entries.id AND ec.username NOT IN (#{EntryComment::USER_TYPE_MAP.keys.map(&:inspect).join(', ')}))"}
      }],
      [163, :ent_first_sale_savings, :ent_first_sale_savings, "First Sale Savings", {:data_type=>:decimal, :read_only=>true,
        :import_lambda=>lambda {|obj, data| "First Sale Savings ignored. (read only)"},
        :export_lambda=>lambda { |obj| obj.first_sale_savings },
        :qualified_field_name=> "IFNULL((SELECT SUM(ROUND((cil.contract_amount - cil.value) * IFNULL((SELECT cit.duty_amount / cit.entered_value
                                                                                                      FROM commercial_invoice_tariffs cit
                                                                                                      WHERE cit.commercial_invoice_line_id = cil.id ORDER BY cit.id limit 1), 0), 2))
                                         FROM commercial_invoices inv
                                         INNER JOIN commercial_invoice_lines cil ON inv.id = cil.commercial_invoice_id
                                         WHERE entries.id = inv.entry_id AND cil.contract_amount > 0), 0)"
      }],
      [164, :ent_cancelled_date, :cancelled_date, "Cancelled Date", {:data_type=>:datetime}],
      [165, :ent_arrival_notice_receipt_date, :arrival_notice_receipt_date, "Arrival Notice Receipt Date", {:data_type=>:datetime}],
      [166, :ent_total_non_dutiable_amount, :total_non_dutiable_amount, "Total Non-Dutiable Amount", {data_type: :decimal, currency: :usd}],
      [167, :ent_product_lines, :product_lines, "Product Lines", {:data_type=>:text}],
      [168, :ent_fiscal_date, :fiscal_date, "Fiscal Date", {:data_type=>:date}],
      [169, :ent_fiscal_month, :fiscal_month, "Fiscal Month", {:data_type=>:integer}],
      [170, :ent_fiscal_year, :fiscal_year, "Fiscal Year", {:data_type=>:integer}],
      [171, :ent_other_fees, :other_fees, "Other Taxes & Fees", {data_type: :decimal, currency: :usd}],
      [172, :ent_summary_rejected, :summary_rejected, "Summary Rejected", {data_type: :boolean}],
      [173, :ent_container_count, :container_count, "Container Count", {
        data_type: :integer,
        read_only: true,
        export_lambda: lambda {|ent| ent.containers.length},
        qualified_field_name: "(SELECT COUNT(*) FROM containers WHERE containers.entry_id = entries.id)"
      }],
      [174, :ent_release_type, :release_type, "CBSA Release Type", {data_type: :string}],
      [175, :ent_documentation_request_date, :documentation_request_date, "Documentation Request Date", {:data_type=>:datetime}],
      [176, :ent_po_request_date, :po_request_date, "PO Request Date", {:data_type=>:datetime}],
      [177, :ent_tariff_request_date, :tariff_request_date, "Tariff Request Date", {:data_type=>:datetime}],
      [178, :ent_ogd_request_date, :ogd_request_date, "OGD Request Date", {:data_type=>:datetime}],
      [179, :ent_value_currency_request_date, :value_currency_request_date, "Value/Currency Request Date", {:data_type=>:datetime}],
      [180, :ent_part_number_request_date, :part_number_request_date, "Part Number Request Date", {:data_type=>:datetime}],
      [181, :ent_importer_request_date, :importer_request_date, "Importer Request Date", {:data_type=>:datetime}],
      [182, :ent_manifest_info_received_date, :manifest_info_received_date, "Manifest Info Received Date", {:data_type=>:datetime}],
      [183, :ent_ams_hold_date, :ams_hold_date, "AMS Hold Date", {:data_type=>:datetime}],
      [184, :ent_ams_hold_release_date, :ams_hold_release_date, "AMS Hold Release Date", {:data_type=>:datetime}],
      [185, :ent_aphis_hold_date, :aphis_hold_date, "APHIS Hold Date", {:data_type=>:datetime}],
      [186, :ent_aphis_hold_release_date, :aphis_hold_release_date, "APHIS Hold Release Date", {:data_type=>:datetime}],
      [187, :ent_atf_hold_date, :atf_hold_date, "ATF Hold Date", {:data_type=>:datetime}],
      [188, :ent_atf_hold_release_date, :atf_hold_release_date, "ATF Hold Release Date", {:data_type=>:datetime}],
      [189, :ent_cargo_manifest_hold_date, :cargo_manifest_hold_date, "Cargo Manifest Hold Date", {:data_type=>:datetime}],
      [190, :ent_cargo_manifest_hold_release_date, :cargo_manifest_hold_release_date, "Cargo Manifest Hold Release Date", {:data_type=>:datetime}],
      [191, :ent_cbp_hold_date, :cbp_hold_date, "CBP Hold Date", {:ata_type=>:datetime}],
      [192, :ent_cbp_hold_release_date, :cbp_hold_release_date, "CBP Hold Release Date", {:data_type=>:datetime}],
      [193, :ent_cbp_intensive_hold_date, :cbp_intensive_hold_date, "CBP Intensive Hold Date", {:data_type=>:datetime}],
      [194, :ent_cbp_intensive_hold_release_date, :cbp_intensive_hold_release_date, "CBP Intensive Hold Release Date", {:data_type=>:datetime}],
      [195, :ent_ddtc_hold_date, :ddtc_hold_date, "DDTC Hold Date", {:data_type=>:datetime}],
      [196, :ent_ddtc_hold_release_date, :ddtc_hold_release_date, "DDTC Hold Release Date", {:data_type=>:datetime}],
      [197, :ent_fda_hold_date, :fda_hold_date, "FDA Hold Date", {:data_type=>:datetime}],
      [198, :ent_fda_hold_release_date, :fda_hold_release_date, "FDA Hold Release Date", {:data_type=>:datetime}],
      [199, :ent_fsis_hold_date, :fsis_hold_date, "FSIS Hold Date", {:data_type=>:datetime}],
      [200, :ent_fsis_hold_release_date, :fsis_hold_release_date, "FSIS Hold Release Date", {:data_type=>:datetime}],
      [201, :ent_nhtsa_hold_date, :nhtsa_hold_date, "NHTSA Hold Date", {:data_type=>:datetime}],
      [202, :ent_nhtsa_hold_release_date, :nhtsa_hold_release_date, "NHTSA Hold Release Date", {:data_type=>:datetime}],
      [203, :ent_nmfs_hold_date, :nmfs_hold_date, "NMFS Hold Date", {:data_type=>:datetime}],
      [204, :ent_nmfs_hold_release_date, :nmfs_hold_release_date, "NMFS Hold Release Date", {:data_type=>:datetime}],
      [205, :ent_usda_hold_date, :usda_hold_date, "USDA Hold Date", {:data_type=>:datetime}],
      [206, :ent_usda_hold_release_date, :usda_hold_release_date, "USDA Hold Release Date", {:data_type=>:datetime}],
      [207, :ent_other_agency_hold_date, :other_agency_hold_date, "Other Agency Hold Date", {:data_type=>:datetime}],
      [208, :ent_other_agency_hold_release_date, :other_agency_hold_release_date, "Other Agency Hold Release Date", {:data_type=>:datetime}],
      [209, :ent_one_usg_date, :one_usg_date, "One USG Date", {:data_type=>:datetime}],
      [210, :ent_hold_date, :hold_date, "Hold Date", {
        :data_type=>:datetime,
        :read_only=>true,
        :import_lambda=> lambda { |obj, data| "Hold Date ignored. (read only)" }}],
      [211, :ent_hold_release_date, :hold_release_date, "Hold Release Date", {
        :data_type=>:datetime,
        :read_only=>true,
        :import_lambda=> lambda { |obj, data| "Hold Release Date ignored. (read only)"}}],
      [212, :ent_on_hold, :on_hold, "On Hold", {
        :data_type=>:boolean,
        :read_only=>true,
        :import_lambda=> lambda { |obj, data| "On Hold ignored. (read only)"}}],
      [213, :ent_exam_release_date, :exam_release_date, "CBSA Exam Release Date", {:data_type=>:datetime}],
      [214, :ent_entry_filer, :entry_filer, "Entry Filer", {
        :import_lambda=>lambda {|obj, data| "Entry Filer ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.entry_number ? (obj.canadian? ? obj.entry_number[0, 5] : obj.entry_number[0, 3]) : nil},
        :qualified_field_name=>"(IF(entry_number IS NOT NULL, IF((SELECT iso_code FROM countries WHERE countries.id = entries.import_country_id) = 'CA', LEFT(entry_number, 5), LEFT(entry_number, 3)), null))",
        :data_type=>:string
      }],
      [215, :ent_total_miscellaneous_discount, :total_miscellaneous_discount, "Total Miscellaneous Discount", {
        :data_type=>:decimal,
        :import_lambda=>lambda {|obj, data| "Commercial Invoice Line Count ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.commercial_invoice_lines.sum(:miscellaneous_discount)},
        :qualified_field_name=>"(SELECT SUM(cil.miscellaneous_discount) FROM commercial_invoice_lines AS cil INNER JOIN commercial_invoices AS ci ON ci.id = cil.commercial_invoice_id WHERE ci.entry_id = entries.id)"
      }],
      [216, :ent_import_date, :import_date, "Import Date", {data_type: :date}],
      [217, :ent_split_shipment, :split_shipment, "Split Shipment", {data_type: :boolean,
        export_lambda: lambda {|obj| obj.split_shipment? },
        qualified_field_name: "IFNULL(split_shipment, false)"
      }],
      [218, :ent_split_release_option, :split_release_option, "Split Release Option", {data_type: :string,
        export_lambda: lambda {|obj| obj.split_release_option_value },
        qualified_field_name: "(CASE split_release_option WHEN '1' THEN 'Hold All' WHEN '2' THEN 'Incremental' ELSE '' END)"
      }],
      [219, :ent_first_release_received_date, :first_release_received_date, "First Release Received Date", {data_type: :datetime}],
      [220, :ent_total_billed_duty_amount, :total_billed_duty_amount, "Total Billed Duty Amount", {:data_type=>:decimal, :currency=>:usd, read_only: true,
        :export_lambda=>lambda {|obj| obj.total_billed_duty_amount },
        :qualified_field_name=>Entry.total_duty_billed_subquery
      }],
      [221, :ent_total_taxes, :total_taxes, "Total Taxes", {data_type: :decimal, currency: :usd}],
      [222, :ent_total_duty_taxes_fees_penalties, :total_duty_taxes_fees_penalties, "Total Duty, Taxes, Fees & Penalties", {:data_type=>:decimal, :currency=>:usd, read_only: true,
        :export_lambda=>lambda {|obj| obj.total_duty_taxes_fees_amount },
        :qualified_field_name=>"(IFNULL(entries.total_duty,0) + IFNULL(entries.total_taxes,0) + IFNULL(entries.total_fees,0) + IFNULL(entries.total_cvd,0) + IFNULL(entries.total_add,0))"
      }],
      [223, :ent_fish_and_wildlife_transmitted_date, :fish_and_wildlife_transmitted_date, "Fish & Wildlife Transmitted Date", {data_type: :datetime}],
      [224, :ent_fish_and_wildlife_secure_facility_date, :fish_and_wildlife_secure_facility_date, "Fish & Wildlife Secure Facility Date", {data_type: :datetime}],
      [225, :ent_fish_and_wildlife_hold_date, :fish_and_wildlife_hold_date, "Fish & Wildlife Hold Date", {
        :data_type => :datetime,
        :read_only => true,
        :import_lambda=> lambda { |obj, data| "Fish & Wildlife Hold Date ignored. (read only)"}
      }],
      [226, :ent_fish_and_wildlife_hold_release_date, :fish_and_wildlife_hold_release_date, "Fish & Wildlife Hold Release Date", {
        :data_type => :datetime,
        :read_only => true,
        :import_lambda  => lambda { |obj, data| "Fish & Wildlife Hold Release Date ignored. (read only)"}
      }],
      [227, :ent_fish_and_wildlife_secure_facility, :fish_and_wildlife_secure_facility, "Fish & Wildlife Secure Facility", {
        :data_type => :boolean,
        :export_lambda => lambda { |obj| obj.fish_and_wildlife_secure_facility_date.present? },
        :qualified_field_name => "(SELECT IF(fish_and_wildlife_secure_facility_date IS NOT NULL, true, false))",
        :import_lambda => lambda { |obj, data| "Fish & Wildlife Secure Facility ignored. (read only)"}
      }],
      [228, :ent_split_shipment_date, :split_shipment_date, "Split Shipment Date", {:data_type => :datetime}],
      [229, :ent_across_declaration_accepted, :across_declaration_accepted, "ACROSS - Declaration Accepted", {data_type: :datetime}],
      [230, :ent_summary_line_count, :summary_line_count, "Entry Summary Line Count", {data_type: :integer}],
      [231, :ent_post_summary_exists, :post_summary_exists, "Post Summary Correction", {
        data_type: :boolean,
        read_only: true,
        :import_lambda=>lambda {|obj, data| "Post Summary Corrections Date Exists ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.commercial_invoice_lines.any? { |cil| cil.psc_date? }},
        :qualified_field_name=>"(SELECT CASE WHEN (
          SELECT COUNT(*) FROM commercial_invoice_lines cil
            JOIN commercial_invoices ci ON ci.id = cil.commercial_invoice_id
          WHERE entries.id = ci.entry_id AND cil.psc_date IS NOT NULL)
          THEN 1 ELSE 0 END)"
        }
      ],
      [232, :ent_special_tariff, :special_tariff, "Special Tariff", {data_type: :boolean}],
      [233, :ent_total_value_tax, :total_value_tax, "Total Value for Tax", {
        :data_type=>:decimal,
        :read_only=>true,
        :import_lambda=>lambda {|obj, data| "Total Value for Tax ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.value_for_tax },
        qualified_field_name: <<-SQL
          (SELECT sum(
            IFNULL(commercial_invoice_tariffs.entered_value,0) +
            IFNULL(commercial_invoice_tariffs.duty_amount,0) +
            IFNULL(commercial_invoice_tariffs.sima_amount,0) +
            IFNULL(commercial_invoice_tariffs.excise_amount,0))
          FROM
            commercial_invoice_tariffs
            JOIN (commercial_invoice_lines, commercial_invoices)
            ON (commercial_invoice_lines.id = commercial_invoice_tariffs.commercial_invoice_line_id
              AND commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id)
          WHERE commercial_invoices.entry_id = entries.id
            AND commercial_invoice_tariffs.value_for_duty_code IS NOT NULL)
        SQL
      }],
      [244, :ent_master_bills_of_lading_count, :master_bills_of_lading_count, "Total Master Bills of Lading", {
          :data_type=>:integer,
          :read_only=>true,
          :import_lambda=>lambda { |obj, data| "Total Master Bills of Lading ignored. (read only)" },
          :export_lambda=>lambda { |obj| obj.master_bills_of_lading.present? ? obj.split_newline_values(obj.master_bills_of_lading).length : 0 },
          qualified_field_name: <<-SQL
            (IF((entries.master_bills_of_lading IS NOT NULL AND entries.master_bills_of_lading <> ""), (CHAR_LENGTH(entries.master_bills_of_lading) - CHAR_LENGTH(REPLACE(entries.master_bills_of_lading, '\n', '')) + 1), 0))
          SQL
      }],
      [245, :ent_house_bills_of_lading_count, :house_bills_of_lading_count, "Total House Bills of Lading", {
          :data_type=>:integer,
          :read_only=>true,
          :import_lambda=>lambda { |obj, data| "Total House Bills of Lading ignored. (read only)" },
          :export_lambda=>lambda { |obj| obj.house_bills_of_lading.present? ? obj.split_newline_values(obj.house_bills_of_lading).length : 0 },
          qualified_field_name: <<-SQL
            (IF((entries.house_bills_of_lading IS NOT NULL AND entries.house_bills_of_lading <> ""), (CHAR_LENGTH(entries.house_bills_of_lading) - CHAR_LENGTH(REPLACE(entries.house_bills_of_lading, '\n', '')) + 1), 0))
          SQL
      }],
      [246, :ent_k84_payment_due_date, :k84_payment_due_date, "K84 Payment Due Date", {:data_type=>:date}],
      [247, :ent_broker_invoice_list, :broker_invoice_list, "Broker Invoice Number(s)", {
          :data_type=>:string,
          :read_only=>true,
          :import_lambda=>lambda { |obj, data| "Broker Invoice numbers ignored. (read only)"},
          :export_lambda=>lambda { |obj| obj.broker_invoices.map {|bi| bi.invoice_number}.uniq.join("\n") },
          :qualified_field_name=> '(SELECT GROUP_CONCAT(DISTINCT invoice_number SEPARATOR "\n") from broker_invoices as bi where bi.entry_id = entries.id)'
      }],
      [248, :ent_invoice_missing_date, :invoice_missing_date, "Invoice Missing Date", {data_type: :date}],
      [249, :ent_bol_discrepancy_date, :bol_discrepancy_date, "BOL Discrepancy Date", {data_type: :date}],
      [250, :ent_detained_at_port_of_discharge_date, :detained_at_port_of_discharge_date, "Detained at Port of Discharge Date", {data_type: :date}],
      [251, :ent_invoice_discrepancy_date, :invoice_discrepancy_date, "Invoice Discrepancy Date", {data_type: :date}],
      [252, :ent_docs_missing_date, :docs_missing_date, "Docs Missing Date", {data_type: :date}],
      [253, :ent_hts_missing_date, :hts_missing_date, "HTS Missing Date", {data_type: :date}],
      [254, :ent_hts_expired_date, :hts_expired_date, "HTS Expired Date", {data_type: :date}],
      [255, :ent_hts_misclassified_date, :hts_misclassified_date, "HTS Misclassified Date", {data_type: :date}],
      [256, :ent_hts_need_additional_info_date, :hts_need_additional_info_date, "HTS Need Additional Info Date", {data_type: :date}],
      [257, :ent_mid_discrepancy_date, :mid_discrepancy_date, "MID Discrepancy Date", {data_type: :date}],
      [258, :ent_additional_duty_confirmation_date, :additional_duty_confirmation_date, "Additional Duty Confirmation Date", {data_type: :date}],
      [259, :ent_pga_docs_missing_date, :pga_docs_missing_date, "PGA Docs Missing Date", {data_type: :date}],
      [260, :ent_pga_docs_incomplete_date, :pga_docs_incomplete_date, "PGA Docs Incomplete Date", {data_type: :date}],
      [261, :ent_exception, :exception, "Exception Flag", {
        data_type: :boolean,
        read_only: true,
        import_lambda: lambda { |obj, data| "Exception Flag ignored. (read only)" },
        export_lambda: lambda { |obj| Entry.milestone_exception_fields.map { |f| obj.public_send f }.any? },
        qualified_field_name: <<-SQL
          (IF(#{Entry.milestone_exception_fields.map { |f| "entries.#{f}" }.join(" OR ")}, true, false))
        SQL
      }],
      [262, :ent_consignee_postal_code, :consignee_postal_code, "Ult Consignee Postal Code", {:data_type=>:string}],
      [263, :ent_consignee_country_code, :consignee_country_code, "Ult Consignee Country", {:data_type=>:string}],
      [264, :ent_miscellaneous_entry_exception_date, :miscellaneous_entry_exception_date, "Misc Entry Exception Date", {data_type: :date}],
      [265, :ent_daily_statement_duty_amount_paid, :daily_statement_duty_amount_paid, "Statement Duty Amt Paid", {
        data_type: :decimal,
        read_only: true,
        export_lambda: lambda { |obj| obj.daily_statement_entry.present? ? obj.daily_statement_entry.duty_amount : 0},
        qualified_field_name: "(SELECT duty_amount FROM daily_statement_entries dse WHERE dse.entry_id = entries.id)"
      }],
      [266, :ent_daily_statement_tax_amount_paid, :daily_statement_tax_amount_paid, "Statement Tax Amount Paid", {
          data_type: :decimal,
          read_only: true,
          export_lambda: lambda { |obj| obj.daily_statement_entry.present? ? obj.daily_statement_entry.tax_amount : 0},
          qualified_field_name: "(SELECT tax_amount FROM daily_statement_entries dse WHERE dse.entry_id = entries.id)"
      }],
      [267, :ent_daily_statement_add_amount_paid, :daily_statement_add_amount_paid, "Statement ADD Amount Paid", {
          data_type: :decimal,
          read_only: true,
          export_lambda: lambda { |obj| obj.daily_statement_entry.present? ? obj.daily_statement_entry.add_amount : 0},
          qualified_field_name: "(SELECT add_amount FROM daily_statement_entries dse WHERE dse.entry_id = entries.id)"
      }],
      [268, :ent_daily_statement_cvd_amount_paid, :daily_statement_cvd_amount_paid, "Statement CVD Amount Paid", {
          data_type: :decimal,
          read_only: true,
          export_lambda: lambda { |obj| obj.daily_statement_entry.present? ? obj.daily_statement_entry.cvd_amount : 0},
          qualified_field_name: "(SELECT cvd_amount FROM daily_statement_entries dse WHERE dse.entry_id = entries.id)"
      }],
      [269, :ent_daily_statement_fee_amount_paid, :daily_statement_fee_amount_paid, "Statement Fee Amount Paid", {
          data_type: :decimal,
          read_only: true,
          export_lambda: lambda { |obj| obj.daily_statement_entry.present? ? obj.daily_statement_entry.fee_amount : 0},
          qualified_field_name: "(SELECT fee_amount FROM daily_statement_entries dse WHERE dse.entry_id = entries.id)"
      }],
      [270, :ent_daily_statement_total_amount_paid, :daily_statement_total_amount_paid, "Statement Total Amount Paid", {
          data_type: :decimal,
          read_only: true,
          export_lambda: lambda { |obj| obj.daily_statement_entry.present? ? obj.daily_statement_entry.total_amount : 0},
          qualified_field_name: "(SELECT total_amount FROM daily_statement_entries dse WHERE dse.entry_id = entries.id)"
      }],
      [271, :ent_trucker_names, :trucker_names, "Trucker Name(s)", data_type: :string],
      [272, :ent_deliver_to_names, :deliver_to_names, "Deliver To Name(s)", data_type: :string],
      [273, :ent_summary_accepted_date, :summary_accepted_date, "Summary Accepted Date", {:data_type=>:datetime}],
      [274, :ent_bond_surety_number, :bond_surety_number, "Bond Surety Number", {:data_type=>:string}],
      [275, :ent_open_exception_codes, :open_exception_codes, "Open Exception Codes", {
          :data_type=>:string,
          :read_only=>true,
          :import_lambda=>lambda {|obj, data| "Open Exception Codes ignored. (read only)"},
          :export_lambda=>lambda { |obj|
            obj.entry_exceptions.select { |eex| eex.resolved_date.nil? }.map { |eex| eex.code }.uniq.join("\n")
          },
          :qualified_field_name=> '(SELECT GROUP_CONCAT(DISTINCT eex.code SEPARATOR "\n") FROM entry_exceptions AS eex WHERE eex.entry_id = entries.id AND eex.resolved_date IS NULL)'
      }],
      [276, :ent_resolved_exception_codes, :resolved_exception_codes, "Resolved Exception Codes", {
          :data_type=>:string,
          :read_only=>true,
          :import_lambda=>lambda {|obj, data| "Resolved Exception Codes ignored. (read only)"},
          :export_lambda=>lambda { |obj|
            obj.entry_exceptions.select { |eex| eex.resolved_date.present? }.map { |eex| eex.code }.uniq.join("\n")
          },
          :qualified_field_name=> '(SELECT GROUP_CONCAT(DISTINCT eex.code SEPARATOR "\n") FROM entry_exceptions AS eex WHERE eex.entry_id = entries.id AND eex.resolved_date IS NOT NULL)'
      }],
      [277, :ent_customs_detention_exception_opened_date, :customs_detention_exception_opened_date, "Customs Detention Exception Opened Date", {:data_type=>:datetime}],
      [278, :ent_customs_detention_exception_resolved_date, :customs_detention_exception_resolved_date, "Customs Detention Exception Resolved Date", {:data_type=>:datetime}],
      [279, :ent_classification_inquiry_exception_opened_date, :classification_inquiry_exception_opened_date, "Classification Inquiry Exception Opened Date", {:data_type=>:datetime}],
      [280, :ent_classification_inquiry_exception_resolved_date, :classification_inquiry_exception_resolved_date, "Classification Inquiry Exception Resolved Date", {:data_type=>:datetime}],
      [281, :ent_customer_requested_hold_exception_opened_date, :customer_requested_hold_exception_opened_date, "Customer Requested Hold Exception Opened Date", {:data_type=>:datetime}],
      [282, :ent_customer_requested_hold_exception_resolved_date, :customer_requested_hold_exception_resolved_date, "Customer Requested Hold Exception Resolved Date", {:data_type=>:datetime}],
      [283, :ent_customs_exam_exception_opened_date, :customs_exam_exception_opened_date, "Customs Exam Exception Opened Date", {:data_type=>:datetime}],
      [284, :ent_customs_exam_exception_resolved_date, :customs_exam_exception_resolved_date, "Customs Exam Exception Resolved Date", {:data_type=>:datetime}],
      [285, :ent_document_discrepancy_exception_opened_date, :document_discrepancy_exception_opened_date, "Document Discrepancy Exception Opened Date", {:data_type=>:datetime}],
      [286, :ent_document_discrepancy_exception_resolved_date, :document_discrepancy_exception_resolved_date, "Document Discrepancy Exception Resolved Date", {:data_type=>:datetime}],
      [287, :ent_fda_issue_exception_opened_date, :fda_issue_exception_opened_date, "FDA Issue Exception Opened Date", {:data_type=>:datetime}],
      [288, :ent_fda_issue_exception_resolved_date, :fda_issue_exception_resolved_date, "FDA Issue Exception Resolved Date", {:data_type=>:datetime}],
      [289, :ent_fish_and_wildlife_exception_opened_date, :fish_and_wildlife_exception_opened_date, "Fish & Wildlife Exception Opened Date", {:data_type=>:datetime}],
      [290, :ent_fish_and_wildlife_exception_resolved_date, :fish_and_wildlife_exception_resolved_date, "Fish & Wildlife Exception Resolved Date", {:data_type=>:datetime}],
      [291, :ent_lacey_act_exception_opened_date, :lacey_act_exception_opened_date, "Lacey Act Exception Opened Date", {:data_type=>:datetime}],
      [292, :ent_lacey_act_exception_resolved_date, :lacey_act_exception_resolved_date, "Lacey Act Exception Resolved Date", {:data_type=>:datetime}],
      [293, :ent_late_documents_exception_opened_date, :late_documents_exception_opened_date, "Late Documents Exception Opened Date", {:data_type=>:datetime}],
      [294, :ent_late_documents_exception_resolved_date, :late_documents_exception_resolved_date, "Late Documents Exception Resolved Date", {:data_type=>:datetime}],
      [295, :ent_manifest_hold_exception_opened_date, :manifest_hold_exception_opened_date, "Manifest Hold Exception Opened Date", {:data_type=>:datetime}],
      [296, :ent_manifest_hold_exception_resolved_date, :manifest_hold_exception_resolved_date, "Manifest Hold Exception Resolved Date", {:data_type=>:datetime}],
      [297, :ent_missing_document_exception_opened_date, :missing_document_exception_opened_date, "Missing Document Exception Opened Date", {:data_type=>:datetime}],
      [298, :ent_missing_document_exception_resolved_date, :missing_document_exception_resolved_date, "Missing Document Exception Resolved Date", {:data_type=>:datetime}],
      [299, :ent_pending_customs_review_exception_opened_date, :pending_customs_review_exception_opened_date, "Pending Customs Review Exception Opened Date", {:data_type=>:datetime}],
      [300, :ent_pending_customs_review_exception_resolved_date, :pending_customs_review_exception_resolved_date, "Pending Customs Review Exception Resolved Date", {:data_type=>:datetime}],
      [301, :ent_price_inquiry_exception_opened_date, :price_inquiry_exception_opened_date, "Price Inquiry Exception Opened Date", {:data_type=>:datetime}],
      [302, :ent_price_inquiry_exception_resolved_date, :price_inquiry_exception_resolved_date, "Price Inquiry Exception Resolved Date", {:data_type=>:datetime}],
      [303, :ent_usda_hold_exception_opened_date, :usda_hold_exception_opened_date, "USDA Hold Exception Opened Date", {:data_type=>:datetime}],
      [304, :ent_usda_hold_exception_resolved_date, :usda_hold_exception_resolved_date, "USDA Hold Exception Resolved Date", {:data_type=>:datetime}]
    ]
    add_fields CoreModule::ENTRY, make_country_arrays(500, 'ent', "entries", "import_country", association_title: "Import")
    add_fields CoreModule::ENTRY, make_sync_record_arrays(600, 'ent', 'entries', 'Entry')
    add_fields CoreModule::ENTRY, make_attachment_arrays(700, 'ent', CoreModule::ENTRY, {ent_attachment_types: lambda {|u| u.company.master?}})
    add_fields CoreModule::ENTRY, make_business_rule_arrays(800, 'ent', 'entries', 'Entry')
  end
end; end; end
