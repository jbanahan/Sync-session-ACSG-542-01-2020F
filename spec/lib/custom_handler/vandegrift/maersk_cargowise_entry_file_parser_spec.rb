describe OpenChain::CustomHandler::Vandegrift::MaerskCargowiseEntryFileParser do

  describe "parse" do
    let (:log) { InboundFile.new }
    let (:test_data) { IO.read('spec/fixtures/files/maersk_cargowise_entry.xml') }

    before :each do
      allow(subject).to receive(:inbound_file).and_return log
    end

    def parse_datetime date_str
      @zone ||= ActiveSupport::TimeZone["America/New_York"]
      @zone.parse(date_str)
    end

    def make_document xml_str
      doc = Nokogiri::XML xml_str
      doc.remove_namespaces!
      doc
    end

    describe "US" do
      let! (:country) { Factory(:country, iso_code:'US') }

      it "creates a US entry" do
        DataCrossReference.create!(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAICNT', value:'21')

        expect_any_instance_of(Entry).to receive(:create_snapshot).with(User.integration, nil, "this_key")
        expect_any_instance_of(Entry).to receive(:broadcast_event).with(:save)
        expect(subject).to receive(:process_special_tariffs)
        effective_date = Date.new(2016,6,6)
        expect(subject).to receive(:tariff_effective_date).and_return(effective_date).once
        # One for each invoice line (because one for each primary tariff, and there's only one of those per line).
        expect(subject).to receive(:calculate_duty_rates).with(kind_of(CommercialInvoiceTariff), kind_of(CommercialInvoiceLine), effective_date, BigDecimal.new(50760)).twice
        expect(subject).to receive(:calculate_duty_rates).with(kind_of(CommercialInvoiceTariff), kind_of(CommercialInvoiceLine), effective_date, BigDecimal.new(760)).once

        now = Time.zone.parse("2019-04-12 05:06:07")
        Timecop.freeze(now) do
          subject.parse make_document(test_data), { :key=>"this_key", :bucket=>"that_bucket" }
        end

        importer_identifier = SystemIdentifier.where(system: "Cargowise", code: "US48733060").first
        expect(importer_identifier).to_not be_nil
        importer_company = Company.where(importer: true, name: "HOME DEPOT USA INC").first
        expect(importer_company).to_not be_nil

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.source_system).to eq Entry::CARGOWISE_SOURCE_SYSTEM
        expect(entry.import_country_id).to eq country.id
        expect(entry.entry_number).to eq "59555920103"
        expect(entry.master_bills_of_lading).to eq "ZIMU000030320655\n ZIKA000030320659\n ZIMA000030320656"
        expect(entry.house_bills_of_lading).to eq "CNRU000030320657\n SCTV000030320658"
        expect(entry.customer_references).to eq "MAEU579869416"

        expect(entry.release_cert_message).to eq "RELEASED"
        expect(entry.fda_message).to eq "MAY PROCEED"
        expect(entry.paperless_release).to eq true
        expect(entry.error_free_release).to eq true
        expect(entry.customer_number).to eq "US48733060"
        expect(entry.customer_name).to eq "HOME DEPOT USA INC"
        expect(entry.importer_id).to eq importer_company.id
        expect(entry.vendor_names).to eq "GORETECH INDUSTRIES CO LTD\n GORTECH INDUSTRIES CO LTD"
        expect(entry.po_numbers).to eq "5813687318\n 5813687319"
        expect(entry.merchandise_description).to eq "HOME IMPROVEMENT ITEMS"

        expect(entry.export_date).to eq parse_datetime("2019-01-02").to_date
        expect(entry.direct_shipment_date).to eq parse_datetime("2019-01-02").to_date
        expect(entry.docs_received_date).to eq parse_datetime("2019-05-05").to_date
        expect(entry.first_it_date).to eq parse_datetime("2019-01-21").to_date
        expect(entry.eta_date).to eq parse_datetime("2019-02-01").to_date
        expect(entry.arrival_date).to eq parse_datetime("2019-02-22")
        expect(entry.first_release_date).to eq parse_datetime("2019-01-17 00:00:00")
        expect(entry.release_date).to eq parse_datetime("2019-04-15 05:03:00")
        expect(entry.fda_review_date).to be_nil
        expect(entry.fda_release_date).to be_nil
        expect(entry.freight_pickup_date).to eq parse_datetime("2019-01-31T21:46:00")
        expect(entry.final_delivery_date).to eq parse_datetime("2019-02-01T22:46:0")
        expect(entry.free_date).to eq parse_datetime("2019-02-01T23:46:00")
        expect(entry.duty_due_date).to eq parse_datetime("2019-02-15").to_date
        expect(entry.available_date).to eq parse_datetime("2019-02-03T00:46:00")
        expect(entry.import_date).to eq parse_datetime("2019-01-21").to_date
        expect(entry.ams_hold_date).to eq parse_datetime("2019-01-28 16:40:00.000")
        expect(entry.ams_hold_release_date).to eq parse_datetime("2019-01-30 17:40:00.000")
        expect(entry.aphis_hold_date).to eq parse_datetime("2019-01-30 18:40:00.000")
        expect(entry.aphis_hold_release_date).to eq parse_datetime("2019-02-01 19:40:00.000")
        expect(entry.cbp_hold_date).to eq parse_datetime("2019-02-01 20:40:00.000")
        expect(entry.cbp_hold_release_date).to eq parse_datetime("2019-02-03 21:40:00.000")
        expect(entry.cbp_intensive_hold_date).to eq parse_datetime("2019-03-29 16:45:00.000")
        expect(entry.cbp_intensive_hold_release_date).to eq parse_datetime("2019-05-03 01:33:00.000000000")
        expect(entry.fda_hold_date).to be_nil
        expect(entry.fda_hold_release_date).to be_nil
        expect(entry.usda_hold_date).to eq parse_datetime("2019-01-30 18:40:00.000")
        expect(entry.usda_hold_release_date).to eq parse_datetime("2019-02-01 19:40:00.000")
        expect(entry.other_agency_hold_date).to be_nil
        expect(entry.other_agency_hold_release_date).to be_nil
        expect(entry.one_usg_date).to eq parse_datetime("2019-02-01 15:22:00.000")
        expect(entry.last_exported_from_source).to eq now

        expect(entry.entry_port_code).to eq "3901"
        expect(entry.lading_port_code).to eq "57078"
        expect(entry.unlading_port_code).to eq "3604"
        expect(entry.destination_state).to eq "IL"
        expect(entry.entry_type).to eq "01"
        expect(entry.mfids).to eq "CNGORINDZHE\n CNGORINDZHE2"
        expect(entry.export_country_codes).to eq "CN\n IN"
        expect(entry.origin_country_codes).to eq "UR\n PL"
        expect(entry.special_program_indicators).to eq "A\n B"
        expect(entry.voyage).to eq "555333111"
        expect(entry.vessel).to eq "SS Minnow"
        expect(entry.location_of_goods).to eq "I092"
        expect(entry.ult_consignee_name).to eq "HOME DEPOT USA INC"
        expect(entry.transport_mode_code).to eq "21"
        expect(entry.carrier_code).to eq "CNRV"
        expect(entry.carrier_name).to eq "Fisher"

        expect(entry.sub_house_bills_of_lading).to eq "000030320633\n 000030320634"
        expect(entry.it_numbers).to eq "V3843752436\n V3843752437"
        expect(entry.container_numbers).to eq "APMU4593140\n APMU4593141"
        expect(entry.container_sizes).to eq "45HC\n 50HC"
        expect(entry.fcl_lcl).to eq "FCL\n LCL"
        expect(entry.ult_consignee_code).to eq "US48733060"
        expect(entry.importer_tax_id).to eq "58-185331900"
        expect(entry.division_number).to eq "011"
        expect(entry.recon_flags).to eq "NA"
        expect(entry.bond_type).to eq "8"

        expect(entry.total_fees).to eq BigDecimal.new("1627.35")
        expect(entry.total_duty).to eq BigDecimal.new("6598.80")
        expect(entry.total_taxes).to eq BigDecimal.new("111.10")
        expect(entry.total_duty_direct).to be_nil
        expect(entry.total_non_dutiable_amount).to eq BigDecimal.new("2549.86")
        expect(entry.cotton_fee).to eq BigDecimal.new("100.25")
        expect(entry.hmf).to eq BigDecimal.new("100.50")
        expect(entry.mpf).to eq BigDecimal.new("175.83")
        expect(entry.other_fees).to eq BigDecimal.new("51.95")
        expect(entry.entered_value).to eq BigDecimal.new("101520.28")
        expect(entry.total_invoiced_value).to eq BigDecimal.new("51643.45")
        expect(entry.gross_weight).to eq 7397
        expect(entry.total_units).to eq BigDecimal.new("1107.75")
        expect(entry.total_units_uoms).to eq "NO\n NP"
        expect(entry.total_packages).to eq 368
        expect(entry.total_packages_uom).to eq "CT"

        expect(entry.split_shipment).to eq false
        expect(entry.split_release_option).to eq "Split rel"
        expect(entry.summary_line_count).to eq 2
        expect(entry.pay_type).to eq 7
        expect(entry.daily_statement_number).to eq "39190430GO"
        expect(entry.daily_statement_due_date).to eq parse_datetime("2019-02-15").to_date
        expect(entry.daily_statement_approved_date).to eq parse_datetime("2019-02-12").to_date
        expect(entry.monthly_statement_due_date).to eq parse_datetime("2019-03-21").to_date

        expect(entry.cadex_sent_date).to be_nil
        expect(entry.total_gst).to be_nil
        expect(entry.total_duty_gst).to be_nil
        expect(entry.origin_state_codes).to be_nil
        expect(entry.export_state_codes).to be_nil
        expect(entry.cargo_control_number).to be_nil
        expect(entry.ship_terms).to be_nil
        expect(entry.us_exit_port_code).to be_nil
        expect(entry.release_type).to be_nil

        expect(entry.last_file_path).to eq "this_key"
        expect(entry.last_file_bucket).to eq "that_bucket"

        expect(entry.commercial_invoices.length).to eq 2

        ci_1 = entry.commercial_invoices[0]
        expect(ci_1.invoice_number).to eq "5813687318"
        expect(ci_1.mfid).to eq "CNGORINDZHE"
        expect(ci_1.invoice_date).to eq parse_datetime("2018-10-19").to_date
        expect(ci_1.gross_weight).to eq 8397
        expect(ci_1.country_origin_code).to eq "CN"
        expect(ci_1.invoice_value).to eq BigDecimal.new("51520")
        expect(ci_1.total_charges).to eq BigDecimal.new("1790")
        expect(ci_1.invoice_value_foreign).to be_nil
        expect(ci_1.currency).to eq "USD"
        expect(ci_1.total_quantity).to eq BigDecimal.new("368")
        expect(ci_1.total_quantity_uom).to eq "CT"
        expect(ci_1.exchange_rate).to eq BigDecimal.new("1.500000")
        expect(ci_1.non_dutiable_amount).to eq BigDecimal.new("2021.84")
        expect(ci_1.master_bills_of_lading).to eq "CNRU000030320655"
        expect(ci_1.entered_value_7501).to eq 50760
        expect(ci_1.vendor_name).to eq "GORETECH INDUSTRIES CO LTD"
        expect(ci_1.commercial_invoice_lines.length).to eq 2

        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.line_number).to eq 1
        expect(cil_1.po_number).to eq "5813687318"
        expect(cil_1.mid).to eq "CNGORINDZHE"
        expect(cil_1.part_number).to eq "1000053377"
        expect(cil_1.quantity).to eq BigDecimal.new("368")
        expect(cil_1.unit_of_measure).to eq "NO"
        expect(cil_1.value).to eq BigDecimal.new("51520")
        expect(cil_1.country_origin_code).to eq "UR"
        expect(cil_1.country_export_code).to eq "CN"
        expect(cil_1.related_parties).to eq false
        expect(cil_1.vendor_name).to eq "GORETECH INDUSTRIES CO LTD"
        expect(cil_1.volume).to eq BigDecimal.new("22.33")
        expect(cil_1.contract_amount).to eq BigDecimal.new("53.46")
        expect(cil_1.department).to eq "555"
        expect(cil_1.non_dutiable_amount).to eq BigDecimal.new("2037.35")
        expect(cil_1.add_to_make_amount).to eq BigDecimal.new("726.74")
        expect(cil_1.other_amount).to eq BigDecimal.new("31.56")
        expect(cil_1.miscellaneous_discount).to eq BigDecimal.new("236.84")
        expect(cil_1.freight_amount).to eq BigDecimal.new("1790.00")
        expect(cil_1.visa_number).to eq "V1SA"
        expect(cil_1.visa_quantity).to eq BigDecimal.new("2.5")
        expect(cil_1.visa_uom).to eq "EA"
        expect(cil_1.customs_line_number).to eq 1
        expect(cil_1.value_foreign).to be_nil
        expect(cil_1.value_appraisal_method).to eq "F"
        expect(cil_1.currency).to eq "USD"
        expect(cil_1.first_sale).to eq true
        expect(cil_1.unit_price).to eq BigDecimal.new("140")
        expect(cil_1.agriculture_license_number).to eq "554434"
        expect(cil_1.mpf).to eq BigDecimal.new("175.83")
        expect(cil_1.prorated_mpf).to eq BigDecimal.new("1175.83")
        expect(cil_1.hmf).to eq BigDecimal.new("23.45")
        expect(cil_1.cotton_fee).to eq BigDecimal.new("24.46")
        expect(cil_1.other_fees).to eq BigDecimal.new("51.95")
        expect(cil_1.add_case_number).to eq "683838"
        expect(cil_1.add_bond).to eq false
        expect(cil_1.add_case_value).to eq BigDecimal.new("14.92")
        expect(cil_1.add_duty_amount).to eq BigDecimal.new("77.88")
        expect(cil_1.cvd_case_number).to eq "683841"
        expect(cil_1.cvd_bond).to eq true
        expect(cil_1.cvd_case_value).to eq BigDecimal.new("44.33")
        expect(cil_1.cvd_duty_amount).to eq BigDecimal.new("88.77")
        expect(cil_1.state_export_code).to be_nil
        expect(cil_1.state_origin_code).to be_nil
        expect(cil_1.customer_reference).to be_nil
        expect(cil_1.adjustments_amount).to be_nil

        expect(cil_1.commercial_invoice_tariffs.length).to eq 2

        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.hts_code).to eq "8465910047"
        expect(tar_1.duty_advalorem).to eq BigDecimal.new("1015.20")
        expect(tar_1.duty_amount).to eq BigDecimal.new("1522.80")
        expect(tar_1.duty_specific).to eq BigDecimal.new("507.60")
        expect(tar_1.duty_additional).to eq BigDecimal.new("7.00")
        expect(tar_1.entered_value).to eq BigDecimal.new("50760.14")
        expect(tar_1.entered_value_7501).to eq 50760
        expect(tar_1.spi_primary).to eq "A"
        expect(tar_1.spi_secondary).to be_nil
        expect(tar_1.classification_qty_1).to eq BigDecimal.new(368)
        expect(tar_1.classification_uom_1).to eq "NO"
        expect(tar_1.classification_qty_2).to eq BigDecimal.new("13.31")
        expect(tar_1.classification_uom_2).to eq "EA"
        expect(tar_1.classification_qty_3).to eq BigDecimal.new("31.13")
        expect(tar_1.classification_uom_3).to eq "AE"
        expect(tar_1.quota_category).to eq 15515
        expect(tar_1.tariff_provision).to be_nil
        expect(tar_1.value_for_duty_code).to be_nil
        expect(tar_1.special_authority).to be_nil
        expect(tar_1.gst_rate_code).to be_nil
        expect(tar_1.gst_amount).to be_nil
        expect(tar_1.sima_amount).to be_nil
        expect(tar_1.sima_code).to be_nil
        expect(tar_1.gross_weight).to eq 7397
        expect(tar_1.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        tar_2 = cil_1.commercial_invoice_tariffs[1]
        expect(tar_2.hts_code).to eq "99038803"
        expect(tar_2.duty_advalorem).to eq BigDecimal.new("4568.41")
        expect(tar_2.duty_amount).to eq BigDecimal.new("5076.00")
        expect(tar_2.duty_specific).to be_nil
        expect(tar_2.duty_additional).to be_nil
        expect(tar_2.entered_value).to eq BigDecimal.new("0")
        expect(tar_2.entered_value_7501).to eq 0
        expect(tar_2.spi_primary).to be_nil
        expect(tar_2.spi_secondary).to be_nil
        expect(tar_2.classification_qty_1).to be_nil
        expect(tar_2.classification_uom_1).to be_nil
        expect(tar_2.classification_qty_2).to be_nil
        expect(tar_2.classification_uom_2).to be_nil
        expect(tar_2.classification_qty_3).to be_nil
        expect(tar_2.classification_uom_3).to be_nil
        expect(tar_2.quota_category).to be_nil
        expect(tar_2.tariff_provision).to be_nil
        expect(tar_2.value_for_duty_code).to be_nil
        expect(tar_2.special_authority).to be_nil
        expect(tar_2.gst_rate_code).to be_nil
        expect(tar_2.gst_amount).to be_nil
        expect(tar_2.sima_amount).to be_nil
        expect(tar_2.sima_code).to be_nil
        expect(tar_2.gross_weight).to be_nil
        expect(tar_2.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        cil_2 = ci_1.commercial_invoice_lines[1]
        expect(cil_2.line_number).to eq 2
        expect(cil_2.value_appraisal_method).to be_nil
        expect(cil_2.first_sale).to eq false
        expect(cil_2.commercial_invoice_tariffs.length).to eq 2

        ci_2 = entry.commercial_invoices[1]
        expect(ci_2.invoice_number).to eq "5813687319"
        expect(ci_2.commercial_invoice_lines.length).to eq 1

        expect(entry.containers.length).to eq 2

        cont_1 = entry.containers[0]
        expect(cont_1.container_number).to eq "APMU4593140"
        expect(cont_1.container_size).to eq "45HC"
        expect(cont_1.weight).to eq 7397
        expect(cont_1.seal_number).to eq "CN2028936"
        expect(cont_1.fcl_lcl).to eq "FCL"
        expect(cont_1.size_description).to eq "Forty Five foot high cube"

        cont_2 = entry.containers[1]
        expect(cont_2.container_number).to eq "APMU4593141"

        expect(entry.entry_comments.length).to eq 2

        comm_1 = entry.entry_comments[0]
        expect(comm_1.body).to eq "01110319549478000"
        expect(comm_1.username).to eq "Broker"
        expect(comm_1.public_comment).to eq true
        expect(comm_1.generated_at).to eq now

        comm_2 = entry.entry_comments[1]
        expect(comm_2.body).to eq "8675309"
        expect(comm_2.username).to eq "Private Broker"
        expect(comm_2.public_comment).to eq false
        expect(comm_2.generated_at).to eq now

        expect(log).to have_identifier :broker_reference, "BQMJ01119279881", Entry.to_s, entry.id
        expect(log).to have_identifier :import_country, country.iso_code
        expect(log).to have_identifier :entry_number, "59555920103"
        expect(log).to have_identifier :master_bill, "ZIMU000030320655"
        expect(log).to have_identifier :master_bill, "ZIKA000030320659"
        expect(log).to have_identifier :master_bill, "ZIMA000030320656"
        expect(log).to have_identifier :house_bill, "CNRU000030320657"
        expect(log).to have_identifier :house_bill, "SCTV000030320658"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "creates a US entry, hitting secondary paths due to missing values" do
        DataCrossReference.create!(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAICNT', value:'40')

        test_data.gsub!(/EntryAuthorisation/,'EntreeAuthorization')
        test_data.gsub!(/FCLStorageCommences/,'KFCStorageCommences')
        test_data.gsub!(/EntryReleaseDate/,'EntreeReleaseDate')
        test_data.gsub!(/DischargeDate/,'DiscoDate')
        test_data.gsub!(/MasterWayBillIssuerSCAC/,'MrMiyagiIssuerSCAC')
        test_data.gsub!(/TotalWeight/,'ToadWeight')
        test_data.gsub!(/Value>03/,'Value>OhTree')
        test_data.gsub!(/PaperlessRelease/,'PaperlessRelouse')
        test_data.gsub!(/EntryAuthorisation/,'EntryAuthoritarian')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.release_cert_message).to eq "RELEASED"
        expect(entry.first_release_date).to eq parse_datetime("2019-04-30 11:12:00")
        expect(entry.release_date).to eq parse_datetime("2019-05-25 01:33:00.000")
        expect(entry.free_date).to eq nil
        expect(entry.import_date).to eq parse_datetime("2019-02-01").to_date
        expect(entry.carrier_code).to eq "CNRU"
        expect(entry.gross_weight).to eq 15794
        # Because intensive hold date cannot be set, the release date should also be blank.
        expect(entry.cbp_intensive_hold_release_date).to be_nil
        expect(entry.paperless_release).to eq true
        expect(entry.vessel).to eq "CNRU"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "creates a US entry, hitting tertiary paths due to missing values" do
        test_data.gsub!(/EntryReleaseDate/,'EntreeReleaseDate')
        test_data.gsub!(/<ReleaseDate/,'<RelouseDate')
        test_data.gsub!(/<\/ReleaseDate/,'<\/RelouseDate')
        test_data.gsub!(/UDP/,'URP')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.release_cert_message).to be_nil
        expect(entry.release_date).to eq parse_datetime("2019-04-30T11:12:00")

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "updates an existing entry" do
        importer_company = Company.create!(importer: true, name: "HOME DEPOT USA INC")
        importer_identifier = SystemIdentifier.create!(system: "Cargowise", code: "US48733060", company:importer_company)

        exist_entry = Factory(:entry, broker_reference:"BQMJ01119279881", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
        exist_entry.containers.build
        exist_entry.commercial_invoices.build
        exist_entry.entry_comments.build(username:"Private Broker", body:"8675309")
        exist_entry.entry_comments.build(username:"Private Broker", body:"This comment should not be deleted.")
        bi = exist_entry.broker_invoices.build(broker_reference:"X",invoice_date:Date.new(2019,9,9))
        bi.broker_invoice_lines.build(charge_code:"Not deferred", charge_description:"X", charge_amount:1)
        exist_entry.broker_invoices.build(broker_reference:"Y",invoice_date:Date.new(2019,9,10))
        exist_entry.broker_invoices.build(broker_reference:"Y",invoice_date:Date.new(2019,9,8))
        exist_entry.save!

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.id).to eq exist_entry.id
        expect(entry.importer_id).to eq importer_company.id
        expect(entry.total_duty_direct).to be_nil
        expect(entry.last_billed_date).to eq parse_datetime("2019-09-10").to_date

        # Existing invoices and containers should have been purged.  If they had not been, these counts would equal 3.
        expect(entry.commercial_invoices.length).to eq 2
        expect(entry.containers.length).to eq 2

        expect(entry.entry_comments.length).to eq 3

        expect(entry.entry_comments[0].body).to eq "8675309"
        expect(entry.entry_comments[1].body).to eq "This comment should not be deleted."
        expect(entry.entry_comments[2].body).to eq "01110319549478000"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "updates an existing entry with deferred duty broker invoice" do
        exist_entry = Factory(:entry, broker_reference:"BQMJ01119279881", source_system:Entry::CARGOWISE_SOURCE_SYSTEM)
        bi = exist_entry.broker_invoices.build(broker_reference:"X")
        bi.broker_invoice_lines.build(charge_code:"201", charge_description:"X", charge_amount:1)
        exist_entry.save!

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.total_duty_direct).to eq BigDecimal.new("8337.25")

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "rejects when broker reference is missing" do
        test_data.gsub!(/CustomsDeclaration/,'CustomsDucklaration')

        subject.parse make_document(test_data)

        expect(Entry.where(broker_reference:"BQMJ01119279881").first).to be_nil
        expect(log).to_not have_info_message "Entry successfully processed."
        expect(log).to have_reject_message "Broker Reference is required."
      end

      it "rejects when unknown country code is provided" do
        test_data.gsub!(/QMJ/,'POO')

        subject.parse make_document(test_data)

        expect(Entry.where(broker_reference:"BQMJ01119279881").first).to be_nil
        expect(log).to_not have_info_message "Entry successfully processed."
        expect(log).to have_reject_message "Could not determine Country of Origin.  Unknown code provided in 'UniversalShipment/Shipment/DataContext/Company/Code': 'POO'."
      end

      it "raises error when country not found" do
        country.destroy

        expect { subject.parse make_document(test_data) }.to raise_error(LoggedParserFatalError, "Country record for ISO 'US' could not be found.")

        expect(Entry.where(broker_reference:"BQMJ01119279881").first).to be_nil
        expect(log).to_not have_info_message "Entry successfully processed."
        expect(log).to have_error_message "Country record for ISO 'US' could not be found."
      end

      it "raises error when customer number is missing" do
        test_data.gsub!(/US48733060/,'')

        subject.parse make_document(test_data)

        expect(Entry.where(broker_reference:"BQMJ01119279881").first).to be_nil
        expect(log).to_not have_info_message "Entry successfully processed."
        expect(log).to have_reject_message "Customer Number is required."
      end

      it "condenses nested lines" do
        test_data.gsub!(/<ParentLineNo>  /,'<ParentLineNo>1')

        effective_date = Date.new(2016,6,6)
        expect(subject).to receive(:tariff_effective_date).and_return(effective_date).once
        # This should be called only one time per invoice, for the one prime tariff under each.
        expect(subject).to receive(:calculate_classification_related_rates).with(kind_of(CommercialInvoiceTariff), kind_of(CommercialInvoiceLine), effective_date).twice do |tar|
          tar.specific_rate = 5
        end

        subject.parse make_document(test_data), { :key=>"this_key"}

        entry = Entry.where(broker_reference:"BQMJ01119279881").first

        expect(entry.commercial_invoices.length).to eq 2

        ci_1 = entry.commercial_invoices[0]
        expect(ci_1.commercial_invoice_lines.length).to eq 1

        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.line_number).to eq 1
        # Verifies we're setting normal invoice line fields.  No need to check 'em all.  That's done elsewhere.
        expect(cil_1.po_number).to eq "5813687318"
        # These fields contain values pulled from both invoice lines.
        expect(cil_1.non_dutiable_amount).to eq BigDecimal.new("4587.21")
        expect(cil_1.add_to_make_amount).to eq BigDecimal.new("733.27")
        expect(cil_1.other_amount).to eq BigDecimal.new("38.09")
        expect(cil_1.miscellaneous_discount).to eq BigDecimal.new("468.68")
        expect(cil_1.freight_amount).to eq BigDecimal.new("3580.00")

        # The single line should have all 4 tariffs under it.  Only the primary tariff should have SPI set.
        # That field is not set for supplemental tariffs.
        expect(cil_1.commercial_invoice_tariffs.length).to eq 4

        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.hts_code).to eq "8465910047"
        expect(tar_1.duty_amount).to eq BigDecimal.new("1522.8")
        expect(tar_1.duty_rate).to eq BigDecimal.new(".03")
        expect(tar_1.duty_specific).to eq BigDecimal.new("507.6")
#        expect(tar_1.duty_additional).to eq BigDecimal.new("7.00")
        expect(tar_1.entered_value).to eq BigDecimal.new("50760.14")
        expect(tar_1.entered_value_7501).to eq 50760
        expect(tar_1.classification_qty_1).to eq BigDecimal.new(368)
        expect(tar_1.classification_uom_1).to eq "NO"
        expect(tar_1.spi_primary).to eq "A"
        expect(tar_1.classification_qty_2).to eq BigDecimal.new("13.31")
        expect(tar_1.gross_weight).to eq 7397
        expect(tar_1.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        tar_2 = cil_1.commercial_invoice_tariffs[1]
        expect(tar_2.hts_code).to eq "99038803"
        expect(tar_2.duty_amount).to eq BigDecimal.new("5076")
        expect(tar_2.duty_rate).to eq BigDecimal.new("0.1")
        expect(tar_2.duty_specific).to be_nil
        expect(tar_2.duty_additional).to be_nil
        expect(tar_2.entered_value).to eq BigDecimal.new("0")
        expect(tar_2.entered_value_7501).to eq 0
        expect(tar_2.classification_qty_1).to be_nil
        expect(tar_2.classification_uom_1).to be_nil
        expect(tar_2.spi_primary).to be_nil
        expect(tar_2.classification_qty_2).to be_nil
        expect(tar_2.gross_weight).to be_nil
        expect(tar_2.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        tar_3 = cil_1.commercial_invoice_tariffs[2]
        expect(tar_3.hts_code).to eq "8465910048"
        expect(tar_3.duty_amount).to eq BigDecimal.new("122.8")
        expect(tar_3.duty_rate).to eq BigDecimal.new("0")
        expect(tar_3.duty_specific).to be_nil
        expect(tar_3.duty_additional).to be_nil
        expect(tar_3.entered_value).to eq BigDecimal.new("0")
        expect(tar_3.entered_value_7501).to eq 0
        expect(tar_3.classification_qty_1).to be_nil
        expect(tar_3.classification_uom_1).to be_nil
        expect(tar_3.spi_primary).to be_nil
        expect(tar_3.classification_qty_2).to be_nil
        expect(tar_3.gross_weight).to be_nil
        expect(tar_3.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        tar_4 = cil_1.commercial_invoice_tariffs[3]
        expect(tar_4.hts_code).to eq "99038804"
        expect(tar_4.duty_amount).to eq BigDecimal.new("576")
        expect(tar_4.duty_rate).to eq BigDecimal.new("0.758")
        expect(tar_4.duty_specific).to be_nil
        expect(tar_4.duty_additional).to be_nil
        expect(tar_4.entered_value).to eq BigDecimal.new("0")
        expect(tar_4.entered_value_7501).to eq 0
        expect(tar_4.classification_qty_1).to be_nil
        expect(tar_4.classification_uom_1).to be_nil
        expect(tar_4.spi_primary).to be_nil
        expect(tar_4.classification_qty_2).to be_nil
        expect(tar_4.gross_weight).to be_nil
        expect(tar_4.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "condenses nested lines sorted out of order" do
        # In this case, we're trying to merge line 1 (which is now line 3) into line 2.
        test_data.gsub!(/<LineNo>1</,'<LineNo>3<')
        test_data.gsub!(/<ParentLineNo>0</,'<ParentLineNo>2<')

        subject.parse make_document(test_data), { :key=>"this_key"}

        entry = Entry.where(broker_reference:"BQMJ01119279881").first

        expect(entry.commercial_invoices.length).to eq 2

        ci_1 = entry.commercial_invoices[0]
        expect(ci_1.commercial_invoice_lines.length).to eq 1

        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.line_number).to eq 2
        # Verifies we're setting normal invoice line fields.  No need to check 'em all.  That's done elsewhere.
        expect(cil_1.po_number).to eq "5813687318"
        # These fields contain values pulled from both invoice lines.
        expect(cil_1.non_dutiable_amount).to eq BigDecimal.new("4587.21")
        expect(cil_1.add_to_make_amount).to eq BigDecimal.new("733.27")
        expect(cil_1.other_amount).to eq BigDecimal.new("38.09")
        expect(cil_1.miscellaneous_discount).to eq BigDecimal.new("468.68")
        expect(cil_1.freight_amount).to eq BigDecimal.new("3580.00")

        # The single line should have all 4 tariffs under it.  The tariffs from the detail occurring second in the
        # XML should be sorted first.
        expect(cil_1.commercial_invoice_tariffs.length).to eq 4
        expect(cil_1.commercial_invoice_tariffs[0].hts_code).to eq "8465910048"
        expect(cil_1.commercial_invoice_tariffs[1].hts_code).to eq "99038804"
        expect(cil_1.commercial_invoice_tariffs[2].hts_code).to eq "8465910047"
        expect(cil_1.commercial_invoice_tariffs[3].hts_code).to eq "99038803"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "does not condense nested lines when they represent XVV lines" do
        test_data.gsub!(/<ParentLineNo>  /,'<ParentLineNo>1')
        # Overriding this AddInfo element because it's not used for anything.
        test_data.gsub!(/BOMLineExpanded/, 'SetInd')

        subject.parse make_document(test_data), { :key=>"this_key"}

        entry = Entry.where(broker_reference:"BQMJ01119279881").first

        expect(entry.commercial_invoices.length).to eq 2

        ci_1 = entry.commercial_invoices[0]
        # Lines are not condensed.
        expect(ci_1.commercial_invoice_lines.length).to eq 2
        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.commercial_invoice_tariffs.length).to eq 2
        expect(cil_1.commercial_invoice_tariffs[0].spi_secondary).to eq "N"

        cil_2 = ci_1.commercial_invoice_lines[1]
        expect(cil_2.commercial_invoice_tariffs.length).to eq 2

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "handles UniversalInterchange as root element" do
        subject.parse make_document("<UniversalInterchange><Body>#{test_data}</Body></UniversalInterchange>")

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "handles non-USD currency" do
        test_data.gsub!(/USD/,'CAD')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil

        ci_1 = entry.commercial_invoices[0]
        expect(ci_1.invoice_value).to eq BigDecimal.new("77280")
        expect(ci_1.invoice_value_foreign).to eq BigDecimal.new("51520")
        expect(ci_1.currency).to eq "CAD"

        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.value).to eq BigDecimal.new("77280")
        expect(cil_1.value_foreign).to eq BigDecimal.new("51520")
        expect(cil_1.currency).to eq "CAD"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "handles negative specific duty" do
        # This will result in the advalorem duty to be much greater than the duty amount.  Duty amount minus advalorem
        # becomes the specific duty.
        test_data.gsub!(/<Key>Duty/, '<Key>Doodie')
        test_data.gsub!(/SupDuty/, 'SupDude')

        # Prevents value from being cleared by calculate_duty_dates logic.  If we don't do that, we're not actually
        # testing what we need to test.
        expect(subject).to receive(:calculate_duty_rates).at_least(:once) do |tar|
          tar.specific_rate = 5
        end

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        ci_1 = entry.commercial_invoices[0]
        cil_1 = ci_1.commercial_invoice_lines[0]
        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.duty_specific).to eq BigDecimal.new("0")
      end

      it "clears duty specific when specific rate is not set" do
        expect(subject).to receive(:calculate_classification_related_rates).at_least(:once) do |tar|
          tar.specific_rate = nil
          tar.additional_rate = 1
        end

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        ci_1 = entry.commercial_invoices[0]
        cil_1 = ci_1.commercial_invoice_lines[0]
        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.duty_specific).to eq BigDecimal.new("0")
        expect(tar_1.duty_advalorem).to eq BigDecimal.new("1015.20")
      end

      it "clears duty specific and sets duty_advalorem to duty_amount when specific rate and additional rate are not set" do
        expect(subject).to receive(:calculate_classification_related_rates).at_least(:once) do |tar|
          tar.specific_rate = nil
          tar.additional_rate = nil
        end

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        ci_1 = entry.commercial_invoices[0]
        cil_1 = ci_1.commercial_invoice_lines[0]
        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.duty_specific).to eq BigDecimal.new("0")
        expect(tar_1.duty_advalorem).to eq BigDecimal.new("1522.80")
      end

      it "clears duty specific and sets duty_advalorem to duty_amount when specific rate and additional rate are zero" do
        expect(subject).to receive(:calculate_classification_related_rates).at_least(:once) do |tar|
          tar.specific_rate = 0
          tar.additional_rate = 0
        end

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        ci_1 = entry.commercial_invoices[0]
        cil_1 = ci_1.commercial_invoice_lines[0]
        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.duty_specific).to eq BigDecimal.new("0")
        expect(tar_1.duty_advalorem).to eq BigDecimal.new("1522.80")
      end

      it "handles missing BOL variants" do
        test_data.gsub!(/ParentBillNumber/,'ParentWilliamNumber')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.master_bills_of_lading).to eq "ZIMU000030320655\n ZIMA000030320656"

        expect(log).to have_info_message "Entry successfully processed."
      end
    end

    describe "Canada" do
      let! (:country) { Factory(:country, iso_code:'CA') }

      it "creates a Canada entry" do
        test_data.gsub!(/<Code>QMJ/,'<Code>YYZ')
        test_data.gsub!(/USD/,'CAD')

        DataCrossReference.create!(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAICNT', value:'6')

        # These are called only for the US.
        expect(subject).to_not receive(:tariff_effective_date)
        expect(subject).to_not receive(:calculate_duty_rates)

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.source_system).to eq Entry::CARGOWISE_SOURCE_SYSTEM
        expect(entry.import_country_id).to eq country.id
        expect(entry.entry_number).to eq "59555920103"
        expect(entry.master_bills_of_lading).to eq "ZIMU000030320655\n ZIKA000030320659\n ZIMA000030320656"
        expect(entry.house_bills_of_lading).to eq "CNRU000030320657\n SCTV000030320658"

        expect(entry.customer_references).to eq "MAEU579869416"
        expect(entry.fda_message).to eq "MAY PROCEED"
        expect(entry.paperless_release).to eq true
        expect(entry.error_free_release).to eq true
        expect(entry.customer_number).to eq "US48733060b"
        expect(entry.customer_name).to eq "HOME DEPOT CANADA, EH?"
        expect(entry.vendor_names).to eq "GORETECH INDUSTRIES CO LTD\n GORTECH INDUSTRIES CO LTD"
        expect(entry.po_numbers).to eq "5813687318\n 5813687319"
        expect(entry.merchandise_description).to eq "HOME IMPROVEMENT ITEMS"

        expect(entry.export_date).to eq parse_datetime("2019-01-02").to_date
        expect(entry.direct_shipment_date).to eq parse_datetime("2019-01-02").to_date
        expect(entry.docs_received_date).to eq parse_datetime("2019-05-05").to_date
        expect(entry.first_it_date).to eq parse_datetime("2019-01-21").to_date
        expect(entry.eta_date).to eq parse_datetime("2019-02-01").to_date
        expect(entry.arrival_date).to eq parse_datetime("2019-02-22")
        expect(entry.first_release_date).to eq parse_datetime("2019-01-17 00:00:00")
        expect(entry.release_date).to eq parse_datetime("2019-01-17 00:00:00")
        expect(entry.fda_review_date).to be_nil
        expect(entry.fda_release_date).to be_nil
        expect(entry.freight_pickup_date).to eq parse_datetime("2019-01-31T21:46:00")
        expect(entry.final_delivery_date).to eq parse_datetime("2019-02-01T22:46:0")
        expect(entry.free_date).to eq parse_datetime("2019-02-01T23:46:00")
        expect(entry.duty_due_date).to eq parse_datetime("2019-02-15").to_date
        expect(entry.available_date).to eq parse_datetime("2019-02-03T00:46:00")
        expect(entry.import_date).to eq parse_datetime("2019-01-21").to_date
        expect(entry.ams_hold_date).to eq parse_datetime("2019-01-28 16:40:00.000")
        expect(entry.ams_hold_release_date).to eq parse_datetime("2019-01-30 17:40:00.000")
        expect(entry.aphis_hold_date).to eq parse_datetime("2019-01-30 18:40:00.000")
        expect(entry.aphis_hold_release_date).to eq parse_datetime("2019-02-01 19:40:00.000")
        expect(entry.cbp_hold_date).to eq parse_datetime("2019-02-01 20:40:00.000")
        expect(entry.cbp_hold_release_date).to eq parse_datetime("2019-02-03 21:40:00.000")
        expect(entry.cbp_intensive_hold_date).to eq parse_datetime("2019-03-29 16:45:00.000")
        expect(entry.cbp_intensive_hold_release_date).to eq parse_datetime("2019-05-03 01:33:00.000000000")
        expect(entry.fda_hold_date).to be_nil
        expect(entry.fda_hold_release_date).to be_nil
        expect(entry.usda_hold_date).to eq parse_datetime("2019-01-30 18:40:00.000")
        expect(entry.usda_hold_release_date).to eq parse_datetime("2019-02-01 19:40:00.000")
        expect(entry.other_agency_hold_date).to be_nil
        expect(entry.other_agency_hold_release_date).to be_nil
        expect(entry.one_usg_date).to eq parse_datetime("2019-02-01 15:22:00.000")

        expect(entry.entry_port_code).to eq "USCHI"
        expect(entry.lading_port_code).to eq "CNYTN"
        expect(entry.unlading_port_code).to eq "USINL"
        expect(entry.destination_state).to be_nil
        expect(entry.entry_type).to eq "01"
        expect(entry.mfids).to be_nil
        expect(entry.export_country_codes).to eq "ET\n NL"
        expect(entry.origin_country_codes).to eq "ET\n NL"
        expect(entry.special_program_indicators).to be_nil
        expect(entry.voyage).to eq "555333111"
        expect(entry.vessel).to eq "SS Minnow"
        expect(entry.location_of_goods).to eq "I092"
        expect(entry.ult_consignee_name).to eq "HOME DEPOT CANADA, EH?"
        expect(entry.transport_mode_code).to eq "6"
        expect(entry.carrier_code).to eq "DCBA"
        expect(entry.carrier_name).to eq "Clyde"

        expect(entry.sub_house_bills_of_lading).to eq "000030320633\n 000030320634"
        expect(entry.it_numbers).to eq "V3843752436\n V3843752437"
        expect(entry.container_numbers).to eq "APMU4593140\n APMU4593141"
        expect(entry.container_sizes).to eq "45HC\n 50HC"
        expect(entry.fcl_lcl).to eq "FCL\n LCL"
        expect(entry.ult_consignee_code).to eq "US48733060b"
        expect(entry.importer_tax_id).to be_nil
        expect(entry.division_number).to eq "011"
        expect(entry.recon_flags).to eq "NA"
        expect(entry.bond_type).to eq "8"

        expect(entry.total_fees).to eq BigDecimal.new("101.95")
        expect(entry.total_duty).to eq BigDecimal.new("6677.30")
        expect(entry.total_taxes).to eq BigDecimal.new("111.10")
        expect(entry.total_duty_direct).to be_nil
        expect(entry.total_non_dutiable_amount).to eq BigDecimal.new("2549.86")
        expect(entry.cotton_fee).to eq BigDecimal.new("100.25")
        expect(entry.hmf).to eq BigDecimal.new("100.50")
        expect(entry.mpf).to eq BigDecimal.new("175.83")
        expect(entry.other_fees).to eq BigDecimal.new("51.95")
        expect(entry.entered_value).to eq BigDecimal.new("20.00")
        expect(entry.total_invoiced_value).to eq BigDecimal.new("51643.45")
        expect(entry.gross_weight).to eq 7397
        expect(entry.total_units).to eq BigDecimal.new("1107.75")
        expect(entry.total_units_uoms).to eq "NO\n NP"
        expect(entry.total_packages).to eq 882
        expect(entry.total_packages_uom).to eq "MS"

        expect(entry.split_shipment).to eq false
        expect(entry.split_release_option).to eq "Split rel"
        expect(entry.summary_line_count).to eq 3
        expect(entry.pay_type).to eq 7
        expect(entry.daily_statement_number).to eq "39190430GO"
        expect(entry.daily_statement_due_date).to eq parse_datetime("2019-02-15").to_date
        expect(entry.daily_statement_approved_date).to eq parse_datetime("2019-02-12").to_date
        expect(entry.monthly_statement_due_date).to eq parse_datetime("2019-03-21").to_date

        expect(entry.cadex_sent_date).to eq parse_datetime("2019-02-28T15:40:00")
        expect(entry.total_gst).to eq BigDecimal.new("23.45")
        expect(entry.total_duty_gst).to eq BigDecimal.new("6700.75")
        expect(entry.origin_state_codes).to eq "DE\n UT"
        expect(entry.export_state_codes).to eq "PA\n NV"
        expect(entry.cargo_control_number).to eq "cargo_num_567"
        expect(entry.ship_terms).to eq "FOB"
        expect(entry.us_exit_port_code).to eq "55533"
        expect(entry.release_type).to eq "srv_opt_9797"

        expect(entry.commercial_invoices.length).to eq 2

        ci_1 = entry.commercial_invoices[0]
        expect(ci_1.invoice_number).to eq "5813687318"
        expect(ci_1.mfid).to eq "CNGORINDZHE"
        expect(ci_1.invoice_date).to eq parse_datetime("2018-10-19").to_date
        expect(ci_1.gross_weight).to eq 8397
        expect(ci_1.country_origin_code).to eq "CN"
        expect(ci_1.invoice_value).to eq BigDecimal.new("51520")
        expect(ci_1.total_charges).to eq BigDecimal.new("1790")
        expect(ci_1.invoice_value_foreign).to be_nil
        expect(ci_1.currency).to eq "CAD"
        expect(ci_1.total_quantity).to eq BigDecimal.new("368")
        expect(ci_1.total_quantity_uom).to eq "CT"
        expect(ci_1.exchange_rate).to eq BigDecimal.new("1.500000")
        expect(ci_1.non_dutiable_amount).to eq BigDecimal.new("2021.84")
        expect(ci_1.master_bills_of_lading).to eq "CNRU000030320655"
        expect(ci_1.entered_value_7501).to eq 50760
        expect(ci_1.vendor_name).to eq "GORETECH INDUSTRIES CO LTD"
        expect(ci_1.commercial_invoice_lines.length).to eq 2

        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.line_number).to eq 1
        expect(cil_1.po_number).to eq "5813687318"
        expect(cil_1.mid).to be_nil
        expect(cil_1.part_number).to eq "1000053377"
        expect(cil_1.quantity).to eq BigDecimal.new("368")
        expect(cil_1.unit_of_measure).to eq "NO"
        expect(cil_1.value).to eq BigDecimal.new("51520")
        expect(cil_1.country_origin_code).to eq "ET"
        expect(cil_1.country_export_code).to eq "BO"
        expect(cil_1.related_parties).to eq false
        expect(cil_1.vendor_name).to eq "GORETECH INDUSTRIES CO LTD"
        expect(cil_1.volume).to eq BigDecimal.new("22.33")
        expect(cil_1.contract_amount).to eq BigDecimal.new("53.46")
        expect(cil_1.department).to eq "555"
        expect(cil_1.non_dutiable_amount).to eq BigDecimal.new("2037.35")
        expect(cil_1.add_to_make_amount).to eq BigDecimal.new("726.74")
        expect(cil_1.other_amount).to eq BigDecimal.new("31.56")
        expect(cil_1.miscellaneous_discount).to eq BigDecimal.new("236.84")
        expect(cil_1.freight_amount).to eq BigDecimal.new("1790.00")
        expect(cil_1.visa_number).to eq "V1SA"
        expect(cil_1.visa_quantity).to eq BigDecimal.new("2.5")
        expect(cil_1.visa_uom).to eq "EA"
        expect(cil_1.customs_line_number).to eq 1
        expect(cil_1.value_foreign).to be_nil
        expect(cil_1.value_appraisal_method).to eq "F"
        expect(cil_1.currency).to eq "CAD"
        expect(cil_1.first_sale).to eq true
        expect(cil_1.unit_price).to eq BigDecimal.new("140")
        expect(cil_1.agriculture_license_number).to eq "554434"
        expect(cil_1.mpf).to eq BigDecimal.new("175.83")
        expect(cil_1.prorated_mpf).to eq BigDecimal.new("1175.83")
        expect(cil_1.hmf).to eq BigDecimal.new("23.45")
        expect(cil_1.cotton_fee).to eq BigDecimal.new("24.46")
        expect(cil_1.other_fees).to eq BigDecimal.new("51.95")
        expect(cil_1.add_case_number).to eq "683838"
        expect(cil_1.add_bond).to eq false
        expect(cil_1.add_case_value).to eq BigDecimal.new("14.92")
        expect(cil_1.add_duty_amount).to eq BigDecimal.new("77.88")
        expect(cil_1.cvd_case_number).to eq "683841"
        expect(cil_1.cvd_bond).to eq true
        expect(cil_1.cvd_case_value).to eq BigDecimal.new("44.33")
        expect(cil_1.cvd_duty_amount).to eq BigDecimal.new("88.77")
        expect(cil_1.state_export_code).to eq "PA"
        expect(cil_1.state_origin_code).to eq "DE"
        expect(cil_1.customer_reference).to eq "5813687318"
        expect(cil_1.adjustments_amount).to eq BigDecimal.new("151.04")

        expect(cil_1.commercial_invoice_tariffs.length).to eq 2

        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.hts_code).to eq "8465910047"
        expect(tar_1.duty_advalorem).to eq BigDecimal.new("133.54")
        expect(tar_1.duty_amount).to eq BigDecimal.new("140.54")
        expect(tar_1.duty_specific).to eq BigDecimal.new("7.00")
        expect(tar_1.duty_additional).to eq BigDecimal.new("7.00")
        expect(tar_1.entered_value).to eq BigDecimal.new("50760.14")
        expect(tar_1.entered_value_7501).to eq 50760
        expect(tar_1.spi_primary).to eq "A"
        expect(tar_1.spi_secondary).to be_nil
        expect(tar_1.classification_qty_1).to eq BigDecimal.new(368)
        expect(tar_1.classification_uom_1).to eq "NO"
        expect(tar_1.classification_qty_2).to eq BigDecimal.new("14.41")
        expect(tar_1.classification_uom_2).to eq "EB"
        expect(tar_1.classification_qty_3).to eq BigDecimal.new("41.14")
        expect(tar_1.classification_uom_3).to eq "BE"
        expect(tar_1.quota_category).to eq 15515
        expect(tar_1.tariff_provision).to eq "99tc"
        expect(tar_1.value_for_duty_code).to eq "vdc"
        expect(tar_1.special_authority).to eq "auth_num"
        expect(tar_1.gst_rate_code).to eq "33.1"
        expect(tar_1.gst_amount).to eq BigDecimal.new("23.45")
        expect(tar_1.sima_amount).to eq BigDecimal.new("13.00")
        expect(tar_1.sima_code).to eq "11.1"
        expect(tar_1.gross_weight).to eq 7397
        expect(tar_1.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        tar_2 = cil_1.commercial_invoice_tariffs[1]
        expect(tar_2.hts_code).to eq "99038803"
        expect(tar_2.duty_advalorem).to eq BigDecimal.new("133.54")
        expect(tar_2.duty_amount).to eq BigDecimal.new("140.54")
        expect(tar_2.duty_specific).to be_nil
        expect(tar_2.duty_additional).to be_nil
        expect(tar_2.entered_value).to eq BigDecimal.new("0")
        expect(tar_2.entered_value_7501).to eq 0
        expect(tar_2.spi_primary).to be_nil
        expect(tar_2.spi_secondary).to be_nil
        expect(tar_2.classification_qty_1).to be_nil
        expect(tar_2.classification_uom_1).to be_nil
        expect(tar_2.classification_qty_2).to be_nil
        expect(tar_2.classification_uom_2).to be_nil
        expect(tar_2.classification_qty_3).to be_nil
        expect(tar_2.classification_uom_3).to be_nil
        expect(tar_2.quota_category).to be_nil
        expect(tar_2.tariff_provision).to be_nil
        expect(tar_2.value_for_duty_code).to be_nil
        expect(tar_2.special_authority).to be_nil
        expect(tar_2.gst_rate_code).to be_nil
        expect(tar_2.gst_amount).to be_nil
        expect(tar_2.sima_amount).to be_nil
        expect(tar_2.sima_code).to be_nil
        expect(tar_2.gross_weight).to be_nil
        expect(tar_2.tariff_description).to eq "RYB 15 AMP 10\" SLIDE MITER SAW"

        cil_2 = ci_1.commercial_invoice_lines[1]
        expect(cil_2.line_number).to eq 2
        expect(cil_2.value_appraisal_method).to be_nil
        expect(cil_2.first_sale).to eq false
        expect(cil_2.commercial_invoice_tariffs.length).to eq 2

        ci_2 = entry.commercial_invoices[1]
        expect(ci_2.invoice_number).to eq "5813687319"
        expect(ci_2.commercial_invoice_lines.length).to eq 1

        expect(entry.containers.length).to eq 2

        cont_1 = entry.containers[0]
        expect(cont_1.container_number).to eq "APMU4593140"
        expect(cont_1.container_size).to eq "45HC"
        expect(cont_1.weight).to eq 7397
        expect(cont_1.seal_number).to eq "CN2028936"
        expect(cont_1.fcl_lcl).to eq "FCL"
        expect(cont_1.size_description).to eq "Forty Five foot high cube"

        cont_2 = entry.containers[1]
        expect(cont_2.container_number).to eq "APMU4593141"

        expect(log).to have_identifier :broker_reference, "BQMJ01119279881", Entry.to_s, entry.id
        expect(log).to have_identifier :import_country, country.iso_code
        expect(log).to have_identifier :entry_number, "59555920103"
        expect(log).to have_identifier :master_bill, "ZIMU000030320655"
        expect(log).to have_identifier :master_bill, "ZIKA000030320659"
        expect(log).to have_identifier :master_bill, "ZIMA000030320656"
        expect(log).to have_identifier :house_bill, "CNRU000030320657"
        expect(log).to have_identifier :house_bill, "SCTV000030320658"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "creates a Canada entry, hitting secondary paths due to missing values" do
        test_data.gsub!(/<Code>QMJ/,'<Code>YYZ')
        test_data.gsub!(/PortOfDestination/,'ProfOfDivination')
        test_data.gsub!(/PortOfDischarge/,'ProfOfDarkArts')
        test_data.gsub!(/EntryAuthorisation/,'EntryAuthoritarian')
        test_data.gsub!(/ADD/,'CVD')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil
        expect(entry.entry_port_code).to eq "BLAH"
        expect(entry.unlading_port_code).to eq "BLEH"
        expect(entry.release_date).to eq parse_datetime("2019-04-30 11:12:00")
        expect(entry.first_release_date).to eq parse_datetime("2019-04-30 11:12:00")

        ci_1 = entry.commercial_invoices[0]
        cil_1 = ci_1.commercial_invoice_lines[0]
        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.sima_amount).to eq BigDecimal.new("13.00")
        expect(tar_1.sima_code).to eq "11.1"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "creates a Canada entry, hitting tertiary paths due to missing values" do
        test_data.gsub!(/<Code>QMJ/,'<Code>YYZ')
        test_data.gsub!(/ADD/,'SUR')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil

        ci_1 = entry.commercial_invoices[0]
        cil_1 = ci_1.commercial_invoice_lines[0]
        tar_1 = cil_1.commercial_invoice_tariffs[0]
        expect(tar_1.sima_amount).to eq BigDecimal.new("13.00")
        expect(tar_1.sima_code).to eq "11.1"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "handles non-CAD currency" do
        test_data.gsub!(/<Code>QMJ/,'<Code>YYZ')

        subject.parse make_document(test_data)

        entry = Entry.where(broker_reference:"BQMJ01119279881").first
        expect(entry).to_not be_nil

        ci_1 = entry.commercial_invoices[0]
        expect(ci_1.invoice_value).to eq BigDecimal.new("77280")
        expect(ci_1.invoice_value_foreign).to eq BigDecimal.new("51520")
        expect(ci_1.currency).to eq "USD"

        cil_1 = ci_1.commercial_invoice_lines[0]
        expect(cil_1.line_number).to eq 1
        expect(cil_1.value).to eq BigDecimal.new("77280")
        expect(cil_1.value_foreign).to eq BigDecimal.new("51520")
        expect(cil_1.currency).to eq "USD"

        expect(log).to have_info_message "Entry successfully processed."
      end

      it "raises error when customer number is missing" do
        test_data.gsub!(/<Code>QMJ/,'<Code>YYZ')
        test_data.gsub!(/US48733060b/,'')

        subject.parse make_document(test_data)

        expect(Entry.where(broker_reference:"BQMJ01119279881").first).to be_nil
        expect(log).to_not have_info_message "Entry successfully processed."
        expect(log).to have_reject_message "Customer Number is required."
      end
    end
  end

end