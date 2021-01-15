describe OpenChain::CustomHandler::Target::TargetEntryConsolidationReport do

  describe "run_schedulable" do
    it "calls the run_if_able method" do
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_if_able)

      described_class.run_schedulable
    end
  end

  describe "run_if_able" do
    it "calls the actual run method when entry initiations received since the last run" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))
      InboundFile.create!(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser",
                          process_start_date: (make_eastern_date(2019, 9, 30) - 32.minutes),
                          process_end_date: (make_eastern_date(2019, 9, 30) - 31.minutes))

      expect(subject).to receive(:run_entry_consolidation_report)

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_if_able
      end
    end

    it "doesn't do anything if entry initiations received more recently than 30 minutes ago" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))
      # This file is safe: older than 30 minutes ago.
      InboundFile.create!(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser",
                          process_start_date: (make_eastern_date(2019, 9, 30) - 32.minutes),
                          process_end_date: (make_eastern_date(2019, 9, 30) - 31.minutes))
      # This file too new.  Even though there's a file older than 30 minutes, we can't run the report.
      InboundFile.create!(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser",
                          process_start_date: (make_eastern_date(2019, 9, 30) - 30.minutes),
                          process_end_date: (make_eastern_date(2019, 9, 30) - 29.minutes))

      expect(subject).not_to receive(:run_entry_consolidation_report)

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_if_able
      end
    end

    it "doesn't do anything if no entry initiations received since the last run" do
      # This file is older than the last report run date.  Its presence should be ignored: only files
      # from after the last report run date matter.
      InboundFile.create!(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser",
                          process_start_date: make_eastern_date(2019, 9, 28),
                          process_end_date: make_eastern_date(2019, 9, 28))

      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      expect(subject).not_to receive(:run_entry_consolidation_report)

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_if_able
      end
    end

    it "runs again if the report already ran today" do
      # Two hours ago, same day.  This won't matter at all: a prior restriction limiting the report to
      # one run per day was removed.
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: (make_eastern_date(2019, 9, 30) - 2.hours))

      # This file is older than 30 minutes.  Good to go.
      InboundFile.create!(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser",
                          process_start_date: (make_eastern_date(2019, 9, 30) - 32.minutes),
                          process_end_date: (make_eastern_date(2019, 9, 30) - 31.minutes))

      expect(subject).to receive(:run_entry_consolidation_report)

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_if_able
      end
    end
  end

  describe "run_entry_consolidation_report" do
    let(:cdefs) { subject.cdefs }
    let!(:country_us) { Factory(:country, iso_code: "US") }
    let!(:target) { with_customs_management_id(Factory(:importer), "TARGEN") }
    let!(:mailing_list) do
      MailingList.create!(system_code: "Target Entry Consolidation Report",
                          company_id: target.id, name: "X", user: User.integration,
                          email_addresses: "a@b.com")
    end

    it "generates and emails spreadsheet" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading_1 = Factory(:port, schedule_d_code: "1111", name: "Lilliput")
      port_unlading_2 = Factory(:port, schedule_d_code: "2222", name: "Brobdingnag")

      # This shipment has all of the validated fields set to values that won't prevent it from
      # being consolidated.  It will be combined with 2 other shipments matching the same vessel/unlading port
      # combination.  Note that, when combined, their total container count is 100 and total cost is $999,999:
      # these are both the maximum values allowed in one consolidated entry.
      shp_1 = make_shipment_and_identifier "MBOL1", "Monitor", port_unlading_1, container_count: 91
      shp_1.update house_bill_of_lading: "NOPROB"
      prod_1 = Factory(:product)
      us_class_1 = prod_1.classifications.create! country: country_us
      tar_1 = us_class_1.tariff_records.create!
      tar_1.find_and_set_custom_value(cdefs[:tar_fda_flag], false)
      tar_1.find_and_set_custom_value(cdefs[:tar_fws_flag], false)
      tar_1.find_and_set_custom_value(cdefs[:tar_add_case], '')
      tar_1.find_and_set_custom_value(cdefs[:tar_cvd_case], nil)
      tar_1.find_and_set_custom_value(cdefs[:tar_spi_primary], ' ')
      tar_1.save!
      prod_1.find_and_set_custom_value(cdefs[:prod_required_documents], "NOT CITES")
      prod_1.find_and_set_custom_value(cdefs[:prod_aphis], false)
      prod_1.save!
      ord_1 = Factory(:order)
      ol_1 = ord_1.order_lines.create! product: prod_1, price_per_unit: BigDecimal("1000")
      shp_1.shipment_lines.create! product: prod_1, quantity: 999, linked_order_line_id: ol_1.id
      shp_1.find_and_set_custom_value(cdefs[:shp_first_sale], false)
      shp_1.save!

      make_shipment_and_identifier "MBOL2", "Monitor", port_unlading_2

      shp_3 = make_shipment_and_identifier "MBOL3", "Monitor", port_unlading_1, container_count: 5
      ord_3 = Factory(:order)
      ol_3 = ord_3.order_lines.create! product: prod_1, price_per_unit: BigDecimal("100")
      shp_3.shipment_lines.create! product: prod_1, quantity: 9, linked_order_line_id: ol_3.id

      shp_4 = make_shipment_and_identifier "MBOL4", "Monitor", port_unlading_1, container_count: 4
      ord_4 = Factory(:order)
      ol_4 = ord_4.order_lines.create! product: prod_1, price_per_unit: BigDecimal("11")
      shp_4.shipment_lines.create! product: prod_1, quantity: 9, linked_order_line_id: ol_4.id

      make_shipment_and_identifier "MBOL5", "Monitor", port_unlading_2

      make_shipment_and_identifier "MBOL6", "Merrimack", nil
      make_shipment_and_identifier "MBOL7", "Merrimack", nil

      # Doesn't match to anything else.  Excluded.
      make_shipment_and_identifier "MBOL8", "Merrimack", port_unlading_2

      # Air shipment.  Ignored.
      shp_air = make_shipment_and_identifier "MBOL-air", "Monitor", port_unlading_1
      shp_air.update! mode: "Air"

      # First sale shipment.  Ignored.
      shp_first_sale = make_shipment_and_identifier "MBOL-first-sale", "Monitor", port_unlading_1
      shp_first_sale.find_and_set_custom_value(cdefs[:shp_first_sale], true)
      shp_first_sale.save!

      # NVOCC shipment.  Ignored.
      shp_nvocc = make_shipment_and_identifier "MBOL-nvocc", "Monitor", port_unlading_1
      shp_nvocc.update! house_bill_of_lading: "AMAW12345"

      # CITES shipment.  Ignored.
      shp_cites = make_shipment_and_identifier "MBOL-cites", "Monitor", port_unlading_1
      prod_cites = Factory(:product)
      prod_cites.find_and_set_custom_value(cdefs[:prod_required_documents], "THING 1 CITES Certificate THING 2")
      prod_cites.save!
      shp_cites.shipment_lines.create! product: prod_cites

      # APHIS shipment.  Ignored.
      shp_aphis = make_shipment_and_identifier "MBOL-aphis", "Monitor", port_unlading_1
      prod_aphis = Factory(:product)
      prod_aphis.find_and_set_custom_value(cdefs[:prod_aphis], true)
      prod_aphis.save!
      shp_aphis.shipment_lines.create! product: prod_aphis

      # FIFRA shipment.  Ignored.
      shp_fifra = make_shipment_and_identifier "MBOL-fifra", "Monitor", port_unlading_1
      prod_fifra = Factory(:product)
      prod_fifra.find_and_set_custom_value(cdefs[:prod_required_documents], "THING 1 FIFRA THING 2")
      prod_fifra.save!
      shp_fifra.shipment_lines.create! product: prod_fifra

      # FDA shipment.  Ignored.
      shp_fda = make_shipment_and_identifier "MBOL-fda", "Monitor", port_unlading_1
      prod_fda = Factory(:product)
      us_class_fda = prod_fda.classifications.create! country: country_us
      tar_fda = us_class_fda.tariff_records.create!
      tar_fda.find_and_set_custom_value(cdefs[:tar_fda_flag], true)
      tar_fda.save!
      shp_fda.shipment_lines.create! product: prod_fda

      # FWS shipment.  Ignored.
      shp_fws = make_shipment_and_identifier "MBOL-fws", "Monitor", port_unlading_1
      prod_fws = Factory(:product)
      us_class_fws = prod_fws.classifications.create! country: country_us
      tar_fws = us_class_fws.tariff_records.create!
      tar_fws.find_and_set_custom_value(cdefs[:tar_fws_flag], true)
      tar_fws.save!
      shp_fws.shipment_lines.create! product: prod_fws

      # ADD shipment.  Ignored.
      shp_add = make_shipment_and_identifier "MBOL-add", "Monitor", port_unlading_1
      prod_add = Factory(:product)
      us_class_add = prod_add.classifications.create! country: country_us
      tar_add = us_class_add.tariff_records.create!
      tar_add.find_and_set_custom_value(cdefs[:tar_add_case], "Case X")
      tar_add.save!
      shp_add.shipment_lines.create! product: prod_add

      # CVD shipment.  Ignored.
      shp_cvd = make_shipment_and_identifier "MBOL-cvd", "Monitor", port_unlading_1
      prod_cvd = Factory(:product)
      us_class_cvd = prod_cvd.classifications.create! country: country_us
      tar_cvd = us_class_cvd.tariff_records.create!
      tar_cvd.find_and_set_custom_value(cdefs[:tar_cvd_case], "Case X")
      tar_cvd.save!
      shp_cvd.shipment_lines.create! product: prod_cvd

      # FTA shipment.  Ignored.
      shp_fta = make_shipment_and_identifier "MBOL-fta", "Monitor", port_unlading_1
      prod_fta = Factory(:product)
      us_class_fta = prod_fta.classifications.create! country: country_us
      tar_fta = us_class_fta.tariff_records.create!
      tar_fta.find_and_set_custom_value(cdefs[:tar_spi_primary], "Bond")
      tar_fta.save!
      shp_fta.shipment_lines.create! product: prod_fta

      # This shipment is also ignored: the initiation file was received before the last report run, indicating
      # it would have been included on that prior report.
      make_shipment_and_identifier "MBOL-old", "Merrimack", port_unlading_1, file_date: make_eastern_date(2019, 9, 28)

      # Ensuring that we're looking only at Entry Initiation parser inbound files.  Silly, but...
      shp_wrong_parser = Factory(:shipment, mode: "Ocean", vessel: "Merrimack", unlading_port: port_unlading_1, master_bill_of_lading: "MBOL-wrong-parser")
      inf_wrong_parser = InboundFile.create!(parser_name: "SomeOtherShipmentParser", process_start_date: (make_eastern_date(2019, 9, 30) - 31.minutes))
      inf_wrong_parser.identifiers.create!(identifier_type: InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, module_id: shp_wrong_parser.id)

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq ["a@b.com"]
      expect(mail.subject).to eq "Target Entry Consolidation Report"
      expect(mail.body).to include "Attached is the Entry Consolidation Report."

      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      expect(att).not_to be_nil
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      expect(reader.length).to eq 2

      sheet = reader["Possible Consolidations"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 11
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL1", "Monitor", "1111", "Lilliput", 91, 999_000]
      expect(sheet[2]).to eq ["20190930-1", "MBOL3", "Monitor", "1111", "Lilliput", 5, 900]
      expect(sheet[3]).to eq ["20190930-1", "MBOL4", "Monitor", "1111", "Lilliput", 4, 99]
      expect(sheet[4]).to eq [nil, nil, nil, nil, nil, nil, nil]
      expect(sheet[5]).to eq ["20190930-2", "MBOL2", "Monitor", "2222", "Brobdingnag", 0, 0]
      expect(sheet[6]).to eq ["20190930-2", "MBOL5", "Monitor", "2222", "Brobdingnag", 0, 0]
      expect(sheet[7]).to eq [nil, nil, nil, nil, nil, nil, nil]
      expect(sheet[8]).to eq ["20190930-3", "MBOL6", "Merrimack", nil, nil, 0, 0]
      expect(sheet[9]).to eq ["20190930-3", "MBOL7", "Merrimack", nil, nil, 0, 0]
      expect(sheet[10]).to eq [nil, nil, nil, nil, nil, nil, nil]

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 13
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["MBOL-air", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[2]).to eq ["MBOL-first-sale", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[3]).to eq ["MBOL-nvocc", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[4]).to eq ["MBOL-cites", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[5]).to eq ["MBOL-aphis", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[6]).to eq ["MBOL-fifra", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[7]).to eq ["MBOL-fda", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[8]).to eq ["MBOL-fws", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[9]).to eq ["MBOL-add", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[10]).to eq ["MBOL-cvd", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[11]).to eq ["MBOL-fta", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[12]).to eq ["MBOL8", "Merrimack", "2222", "Brobdingnag", 0, 0]
    end

    it "does not split grouped shipments to two groups when total value exceeds old maximum" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")
      prod = Factory(:product)
      ord = Factory(:order)

      shp_1 = make_shipment_and_identifier "MBOL1", "Monitor", port_unlading
      ol_1 = ord.order_lines.create! product: prod, price_per_unit: BigDecimal("1000")
      shp_1.shipment_lines.create! product: prod, quantity: 900, linked_order_line_id: ol_1.id
      shp_1.shipment_lines.create! product: prod, quantity: 99, linked_order_line_id: ol_1.id

      shp_2 = make_shipment_and_identifier "MBOL2", "Monitor", port_unlading
      ol_2 = ord.order_lines.create! product: prod, price_per_unit: BigDecimal("100")
      shp_2.shipment_lines.create! product: prod, quantity: 9, linked_order_line_id: ol_2.id

      # Though it shares the same vessel and unlading port as the other two shipments, the combination of
      # its total value with the other two exceeds the former $999,999 max.  Since we're no longer handling
      # this as a special case, it can be lumped into the same group as the others.
      shp_3 = make_shipment_and_identifier "MBOL3", "Monitor", port_unlading
      ol_3 = ord.order_lines.create! product: prod, price_per_unit: BigDecimal("11")
      shp_3.shipment_lines.create! product: prod, quantity: 10, linked_order_line_id: ol_3.id

      shp_4 = make_shipment_and_identifier "MBOL4", "Monitor", port_unlading
      ol_4 = ord.order_lines.create! product: prod, price_per_unit: BigDecimal("11")
      shp_4.shipment_lines.create! product: prod, quantity: 3, linked_order_line_id: ol_4.id

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data

      sheet = reader["Possible Consolidations"]
      expect(sheet.length).to eq 6
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL1", "Monitor", "1111", "Lilliput", 0, 999_000]
      expect(sheet[2]).to eq ["20190930-1", "MBOL2", "Monitor", "1111", "Lilliput", 0, 900]
      expect(sheet[3]).to eq ["20190930-1", "MBOL3", "Monitor", "1111", "Lilliput", 0, 110]
      expect(sheet[4]).to eq ["20190930-1", "MBOL4", "Monitor", "1111", "Lilliput", 0, 33]
      expect(sheet[5]).to eq [nil, nil, nil, nil, nil, nil, nil]

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 1
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
    end

    it "handles case when single shipment's total value exceeds old maximum" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")
      prod = Factory(:product)
      ord = Factory(:order)

      # Total value for this shipment is $1.8 million, much higher than the old $999,999 maximum.  Since we
      # are no longer excluding based on value, it should be included.
      shp_1 = make_shipment_and_identifier "MBOL1", "Monitor", port_unlading
      ol_1 = ord.order_lines.create! product: prod, price_per_unit: BigDecimal("1000")
      shp_1.shipment_lines.create! product: prod, quantity: 900, linked_order_line_id: ol_1.id
      shp_1.shipment_lines.create! product: prod, quantity: 900, linked_order_line_id: ol_1.id

      shp_2 = make_shipment_and_identifier "MBOL2", "Monitor", port_unlading
      ol_2 = ord.order_lines.create! product: prod, price_per_unit: BigDecimal("100")
      shp_2.shipment_lines.create! product: prod, quantity: 9, linked_order_line_id: ol_2.id

      make_shipment_and_identifier "MBOL3", "Monitor", port_unlading

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data

      sheet = reader["Possible Consolidations"]
      expect(sheet.length).to eq 5
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL1", "Monitor", "1111", "Lilliput", 0, 1_800_000]
      expect(sheet[2]).to eq ["20190930-1", "MBOL2", "Monitor", "1111", "Lilliput", 0, 900]
      expect(sheet[3]).to eq ["20190930-1", "MBOL3", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[4]).to eq [nil, nil, nil, nil, nil, nil, nil]

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 1
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
    end

    it "splits grouped shipments to two groups when total container count exceeds maximum" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")

      make_shipment_and_identifier "MBOL1", "Monitor", port_unlading, container_count: 91

      make_shipment_and_identifier "MBOL2", "Monitor", port_unlading, container_count: 5

      # Though it shares the same vessel and unlading port as the other two shipments, the combination of
      # its container quantity with the other two exceeds the 100 max.  It must be split out to its own group.
      make_shipment_and_identifier "MBOL3", "Monitor", port_unlading, container_count: 5

      # Total container count is less than shipment 4 and would fit into the shipment 1/2 consolidation.  We're
      # not trying to be fancy, though, merely moving on to the next group when the threshold is breached by the
      # current shipment, so this should be lumped with shipment 3.
      make_shipment_and_identifier "MBOL4", "Monitor", port_unlading, container_count: 3

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data

      sheet = reader["Possible Consolidations"]
      expect(sheet.length).to eq 7
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL1", "Monitor", "1111", "Lilliput", 91, 0]
      expect(sheet[2]).to eq ["20190930-1", "MBOL2", "Monitor", "1111", "Lilliput", 5, 0]
      expect(sheet[3]).to eq [nil, nil, nil, nil, nil, nil, nil]
      expect(sheet[4]).to eq ["20190930-2", "MBOL3", "Monitor", "1111", "Lilliput", 5, 0]
      expect(sheet[5]).to eq ["20190930-2", "MBOL4", "Monitor", "1111", "Lilliput", 3, 0]
      expect(sheet[6]).to eq [nil, nil, nil, nil, nil, nil, nil]

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 1
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
    end

    it "handles case when single shipment's container count exceeds maximum" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")

      # Container count for this shipment exceeds the 100 max.  It should be excluded.
      make_shipment_and_identifier "MBOL1", "Monitor", port_unlading, container_count: 101

      make_shipment_and_identifier "MBOL2", "Monitor", port_unlading, container_count: 11
      make_shipment_and_identifier "MBOL3", "Monitor", port_unlading, container_count: 11

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data

      sheet = reader["Possible Consolidations"]
      expect(sheet.length).to eq 4
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL2", "Monitor", "1111", "Lilliput", 11, 0]
      expect(sheet[2]).to eq ["20190930-1", "MBOL3", "Monitor", "1111", "Lilliput", 11, 0]
      expect(sheet[3]).to eq [nil, nil, nil, nil, nil, nil, nil]

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 2
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["MBOL1", "Monitor", "1111", "Lilliput", 101, 0]
    end

    it "splits grouped shipments to multiple groups when bill of lading (shipment) count exceeds maximum" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")

      (1..102).each do |i|
        make_shipment_and_identifier "MBOL#{i}", "Monitor", port_unlading
      end

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data

      sheet = reader["Possible Consolidations"]
      expect(sheet.length).to eq 106
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL1", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[2]).to eq ["20190930-1", "MBOL2", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[50]).to eq ["20190930-1", "MBOL50", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[51]).to eq [nil, nil, nil, nil, nil, nil, nil]
      expect(sheet[52]).to eq ["20190930-2", "MBOL51", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[53]).to eq ["20190930-2", "MBOL52", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[101]).to eq ["20190930-2", "MBOL100", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[102]).to eq [nil, nil, nil, nil, nil, nil, nil]
      expect(sheet[103]).to eq ["20190930-3", "MBOL101", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[104]).to eq ["20190930-3", "MBOL102", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[105]).to eq [nil, nil, nil, nil, nil, nil, nil]

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 1
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
    end

    it "removes final shipment when bill of lading (shipment) count is one above maximum" do
      SystemDate.create!(date_type: described_class::LAST_REPORT_RUN, start_date: make_eastern_date(2019, 9, 29))

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")

      (1..51).each do |i|
        make_shipment_and_identifier "MBOL#{i}", "Monitor", port_unlading
      end

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_entry_consolidation_report
      end

      mail = ActionMailer::Base.deliveries.first
      att = mail.attachments["Target_Entry_Consolidation_Report_2019-09-30-120503.xlsx"]
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data

      sheet = reader["Possible Consolidations"]
      expect(sheet.length).to eq 52
      expect(sheet[0]).to eq ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["20190930-1", "MBOL1", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[2]).to eq ["20190930-1", "MBOL2", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[50]).to eq ["20190930-1", "MBOL50", "Monitor", "1111", "Lilliput", 0, 0]
      expect(sheet[51]).to eq [nil, nil, nil, nil, nil, nil, nil]
      # The spillover MBOL, 51, is not included as a group of 1.

      sheet = reader["Excluded"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 2
      expect(sheet[0]).to eq ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]
      expect(sheet[1]).to eq ["MBOL51", "Monitor", "1111", "Lilliput", 0, 0]
    end

    it "raises error if mailing list doesn't exist" do
      mailing_list.destroy!

      expect { subject.run_entry_consolidation_report }.to raise_error("No mailing list exists for 'Target Entry Consolidation Report' system code.")
    end

    it "raises error when US country record not found" do
      country_us.destroy!

      port_unlading = Factory(:port, schedule_d_code: "1111", name: "Lilliput")
      prod = Factory(:product)
      shp = make_shipment_and_identifier "MBOL1", "Monitor", port_unlading
      shp.shipment_lines.create! product: prod

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        expect { subject.run_entry_consolidation_report }.to raise_error "No US country found."
      end
    end

    def make_shipment_and_identifier master_bill, vessel, unlading_port, file_date: (make_eastern_date(2019, 9, 30) - 31.minutes), container_count: 0
      shp = Factory(:shipment, mode: "Ocean", vessel: vessel, unlading_port: unlading_port, master_bill_of_lading: master_bill)
      container_count.times do |i|
        shp.containers.create! container_number: "Container #{i}"
      end

      inf = InboundFile.create!(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser", process_start_date: file_date)
      inf.identifiers.create!(identifier_type: InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, module_id: shp.id)

      shp
    end
  end

  def make_utc_date year, month, day
    ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:05:03")
  end

  def make_eastern_date year, month, day
    dt = make_utc_date(year, month, day)
    dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
    dt
  end

end