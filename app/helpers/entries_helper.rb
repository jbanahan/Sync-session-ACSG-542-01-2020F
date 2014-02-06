module EntriesHelper

  def render_xls entry, user
    # The fields here should mirror what's in the html views for the corresponding entry types
    fields = entry.canadian? ? build_ca_field_arrays : build_us_field_arrays
    wb = XlsMaker.create_workbook "Entry", fields[:entry].collect{|f| f.label(false)}
    sheet = wb.worksheet 0
    XlsMaker.add_body_row sheet, 1, fields[:entry].collect {|f| f.process_export(entry, user)}

    sheet = XlsMaker.create_sheet wb, "Commercial Invoices", (fields[:commercial_invoice] + fields[:commercial_invoice_line] + fields[:commercial_invoice_tariff]).collect{|f| f.label(false)}
    XlsMaker.add_body_row(sheet, 1, ["No Commercial Invoice data."]) if entry.commercial_invoices.length == 0

    row = 0
    entry.commercial_invoices.each do |inv|
      # Render the outer invoice data ahead of time rather than in the innermost loop otherwise we'll be
      # using process_export on the same dataset lots of times
      invoice_data = fields[:commercial_invoice].collect {|f| f.process_export(inv, user)}

      if inv.commercial_invoice_lines.size > 0
        inv.commercial_invoice_lines.each do |line|
          invoice_line_data = fields[:commercial_invoice_line].collect {|f| f.process_export(line, user)}

          if line.commercial_invoice_tariffs.size > 0
            line.commercial_invoice_tariffs.each do |tariff|
              XlsMaker.add_body_row sheet, (row+=1), (invoice_data + invoice_line_data + fields[:commercial_invoice_tariff].collect {|f| f.process_export(tariff, user)})
            end
          else
            XlsMaker.add_body_row sheet, (row+=1), (invoice_data + invoice_line_data)
          end
        end
        
      else
        XlsMaker.add_body_row sheet, (row+=1), invoice_data
      end
    end

    if user.view_broker_invoices?
      sheet = XlsMaker.create_sheet wb, "Broker Invoices", (fields[:broker_invoice] + fields[:broker_invoice_line]).collect{|f| f.label(false)}
      XlsMaker.add_body_row(sheet, 1, ["No Broker Invoice data."]) if entry.broker_invoices.length == 0

      row = 0
      entry.broker_invoices.each do |inv|
        invoice_data = fields[:broker_invoice].collect {|f| f.process_export(inv, user)}

        if inv.broker_invoice_lines.length > 0
          inv.broker_invoice_lines.each do |line|
            XlsMaker.add_body_row sheet, (row+=1), (invoice_data + fields[:broker_invoice_line].collect {|f| f.process_export(line, user)})
          end
        else
          XlsMaker.add_body_row sheet, (row+=1), invoice_data
        end
      end
    end

    wb
  end

  private

    def build_us_field_arrays
      fields = {}
      fields[:entry] = [:ent_entry_num,:ent_brok_ref,:ent_customer_references,:ent_mbols,:ent_hbols,:ent_release_cert_message,:ent_fda_message,:ent_paperless_certification,:ent_paperless_release,:ent_census_warning,:ent_error_free_release,
        :ent_cust_name,:ent_vendor_names,:ent_po_numbers,:ent_merch_desc, :ent_export_date,:ent_docs_received_date,:ent_isf_sent_date,:ent_isf_accepted_date,:ent_first_it_date,:ent_filed_date,:ent_first_entry_sent_date,:ent_eta_date,:ent_arrival_date,:ent_release_date,
        :ent_fda_transmit_date,:ent_fda_review_date,:ent_fda_release_date,:ent_trucker_called_date, :ent_delivery_order_pickup_date, :ent_freight_pickup_date, :ent_free_date,:ent_duty_due_date,
        :ent_last_billed_date,:ent_invoice_paid_date,:ent_edi_received_date,:ent_file_logged_date,:ent_first_7501_print,:ent_last_7501_print,:ent_last_exported_from_source,
        :ent_entry_port_code,:ent_entry_port_name,:ent_lading_port_code,:ent_lading_port_name,:ent_unlading_port_code,:ent_unlading_port_name,:ent_destination_state,:ent_type,:ent_mfids,:ent_export_country_codes,:ent_origin_country_codes,:ent_spis,:ent_vessel,:ent_voyage,
        :ent_ult_con_name,:ent_transport_mode_code,:ent_carrier_code,:ent_sbols,:ent_it_numbers,:ent_container_nums, :ent_container_sizes,:ent_fcl_lcl,:ent_ult_con_code,:ent_cust_num,:ent_comp_num,:ent_div_num,:ent_recon_flags,
        :ent_total_fees,:ent_total_duty,:ent_total_duty_direct,:ent_cotton_fee, :ent_hmf, :ent_mpf,:ent_entered_value,:ent_total_invoiced_value,:ent_gross_weight,:ent_total_units,:ent_total_units_uoms,:ent_total_packages,:ent_total_packages_uom, :ent_broker_invoice_total, :ent_duty_billed,
        :ent_liq_date,:ent_liquidation_total,:ent_liquidation_duty,:ent_liquidation_fees,:ent_liquidation_tax,:ent_liquidation_ada,:ent_liquidation_cvd,:ent_liquidation_type,:ent_liquidation_type_code,:ent_liquidation_action_description,:ent_liquidation_action_code,:ent_liquidation_extension_description,:ent_liquidation_extension_code,:ent_liquidation_extension_count,
        :ent_pay_type,:ent_daily_statement_number,:ent_daily_statement_due_date,:ent_daily_statement_approved_date,:ent_statement_month,:ent_monthly_statement_number,:ent_monthly_statement_due_date,:ent_monthly_statement_received_date,:ent_monthly_statement_paid_date
      ]
      fields[:commercial_invoice] = [:ci_invoice_number,:ci_vendor_name,:ci_mfid,:ci_invoice_date,:ci_gross_weight,:ci_country_origin_code,:ci_invoice_value,:ci_total_charges,:ci_invoice_value_foreign,:ci_currency, :ci_total_quantity, :ci_total_quantity_uom]
      fields[:commercial_invoice_line] = [:cil_part_number,:cil_po_number,:cil_units,:cil_uom,:cil_value,:cil_country_origin_code,:cil_country_export_code,:cil_department,:cil_related_parties,:cil_volume,:cil_hmf,:cil_prorated_mpf,:cil_cotton_fee, :cil_contract_amount,
        :cil_add_case_number, :cil_add_bond, :cil_add_case_value, :cil_add_duty_amount, :cil_add_case_percent,:cil_cvd_case_number, :cil_cvd_bond, :cil_cvd_case_value, :cil_cvd_duty_amount, :cil_cvd_case_percent
      ]
      fields[:commercial_invoice_tariff] = [:cit_hts_code,:cit_duty_amount,:cit_entered_value,:cit_duty_rate,:cit_spi_primary,:cit_spi_secondary,:cit_classification_qty_1,:cit_classification_uom_1,:cit_classification_qty_2,:cit_classification_uom_2,:cit_classification_qty_3,
        :cit_classification_uom_3,:cit_gross_weight,:cit_tariff_description
      ]
      fields[:broker_invoice] = [:bi_invoice_number,:bi_suffix,:bi_invoice_date,:bi_invoice_total,:bi_currency,:bi_to_name,:bi_to_add1,:bi_to_add2,:bi_to_city,:bi_to_state,:bi_to_zip,:bi_to_country_iso]
      fields[:broker_invoice_line] = [:bi_line_charge_code,:bi_line_charge_description,:bi_line_charge_amount,:bi_line_vendor_name,:bi_line_vendor_reference,:bi_line_charge_type]
      find_model_fields fields
    end

    def build_ca_field_arrays
      fields = {}
      fields[:entry] = [:ent_entry_num,:ent_brok_ref,:ent_cust_num, :ent_cust_name, :ent_importer_tax_id,:ent_cargo_control_number,:ent_ca_entry_type,:ent_po_numbers,
          :ent_vendor_names, :ent_customer_references, :ent_total_units,:ent_total_packages, :ent_total_packages_uom, :ent_gross_weight, :ent_total_invoiced_value,:ent_entered_value,:ent_total_duty,:ent_total_gst,:ent_total_duty_gst,
          :ent_direct_shipment_date,:ent_eta_date,:ent_across_sent_date,:ent_pars_ack_date,:ent_pars_reject_date,:ent_release_date,:ent_cadex_sent_date,:ent_cadex_accept_date,:ent_duty_due_date,:ent_file_logged_date,:ent_docs_received_date,:ent_first_do_issued_date, :ent_k84_receive_date, :ent_k84_due_date,
          :ent_entry_port_code,:ent_entry_port_name,:ent_mbols,:ent_hbols,:ent_container_nums,:ent_origin_country_codes,:ent_origin_state_code,:ent_export_country_codes,:ent_export_state_code,:ent_us_exit_port_code,:ent_ship_terms,:ent_transport_mode_code,:ent_carrier_code,:ent_voyage
      ]
      fields[:commercial_invoice] = [:ci_invoice_number,:ci_vendor_name,:ci_invoice_date,:ci_invoice_value,:ci_currency,:ci_exchange_rate]
      fields[:commercial_invoice_line] = [:cil_part_number,:cil_po_number,:cil_customer_reference, :cil_units,:cil_uom,:ent_unit_price,:cil_value,:cil_country_origin_code,:ent_state_origin_code,:cil_country_export_code,:ent_state_export_code]
      fields[:commercial_invoice_tariff] = [:cit_hts_code,:cit_duty_amount,:cit_entered_value,:cit_duty_rate,:cit_spi_primary,:ent_tariff_provision,
        :cit_classification_qty_1,:cit_classification_uom_1,:ent_value_for_duty_code,:ent_gst_rate_code,:ent_gst_amount,:ent_sima_amount,:ent_excise_amount,:ent_excise_rate_code        
      ]
      fields[:broker_invoice] = [:bi_invoice_number,:bi_suffix,:bi_invoice_date,:bi_invoice_total,:bi_currency,:bi_to_name,:bi_to_add1,:bi_to_add2,:bi_to_city,:bi_to_state,:bi_to_zip,:bi_to_country_iso]
      fields[:broker_invoice_line] = [:bi_line_charge_code,:bi_line_charge_description,:bi_line_charge_amount,:bi_line_vendor_name,:bi_line_vendor_reference,:bi_line_charge_type,:bi_line_hst_percent]
      find_model_fields fields
    end

    def find_model_fields fields
      mfs = {}
      fields.each do |k, v|
        mfs[k] = v.collect {|uid| ModelField.find_by_uid(uid)}.compact
      end
      mfs
    end


end
