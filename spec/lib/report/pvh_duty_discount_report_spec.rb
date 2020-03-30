describe OpenChain::Report::PvhDutyDiscountReport do

  describe "permission?" do
    let(:ms) { stub_master_setup }
    let (:u) { Factory(:user) }
    let (:group) { Group.use_system_group 'pvh_duty_discount_report', create: true }

    it "allows access for users who can view entries, are subscribed to report custom feature and are in group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH Duty Discount Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by users who cannot view entries" do
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not subscribed to report custom feature" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH Duty Discount Report").and_return false
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not in the group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH Duty Discount Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return false
      expect(described_class.permission? u).to eq false
    end

    it "creates group if it does not already exist" do
      group.destroy!

      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH Duty Discount Report").and_return true
      expect(u).to receive(:in_group?).and_return false
      expect(described_class.permission? u).to eq false

      group = Group.where(system_code:"pvh_duty_discount_report").first
      expect(group).to_not be_nil
      expect(group.name).to eq "PVH Duty Discount Report"
      expect(group.description).to eq "Users able to run the PVH Duty Discount Report."
    end
  end

  describe "run_report" do
    let (:u) { Factory(:user) }
    let!(:pvh) { Factory(:company, name:'PVH Importer', system_code:'PVH') }

    after { @temp.close if @temp }

    it "generates spreadsheet" do
      fiscal_month = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:1, start_date:Date.new(2018,12,15), end_date:Date.new(2019,1,14))

      entry_1 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", arrival_date:Date.new(2018,12,13), fiscal_date:Date.new(2018,12,15), transport_mode_code:'10', master_bills_of_lading:"A\nB", house_bills_of_lading:"C\nD", fcl_lcl:'LCL')
      inv_1 = entry_1.commercial_invoices.create! invoice_number:"inv-1"
      cont_1 = Container.create! container_number: "cont-1"
      inv_1_line_1 = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:10, value:BigDecimal.new("40.20"), entered_value_7501: 33, part_number:"part-A", container:cont_1, add_to_make_amount:BigDecimal.new("2.22"), first_sale:false, contract_amount:BigDecimal.new("44.44"), non_dutiable_amount:BigDecimal.new("7.65")
      inv_1_line_1_tar_1 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value:nil
      inv_1_line_1_tar_2 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"990379013", duty_rate:BigDecimal.new(".25"), entered_value:22, special_tariff:true
      inv_1_line_1_tar_3 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"990279014", duty_rate:BigDecimal.new(".10"), entered_value:11, special_tariff:true
      inv_1_line_1_tar_4 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679015", duty_rate:BigDecimal.new(".02"), entered_value:nil
      inv_1_line_2 = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:11, value:BigDecimal.new("51.21"), entered_value_7501:44, part_number:"part-B", container:cont_1, add_to_make_amount:BigDecimal.new("1.21"), first_sale:nil, contract_amount:BigDecimal.new("45.45"), non_dutiable_amount:BigDecimal.new("7.64")
      inv_1_line_2_tar = inv_1_line_2.commercial_invoice_tariffs.create! hts_code:"356790123", duty_rate:BigDecimal.new(".667"), entered_value:44
      # This line should be ignored because it's marked first sale.
      inv_1_line_first_sale = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:11, value:BigDecimal.new("51.21"), entered_value_7501:44, part_number:"part-B", container:cont_1, add_to_make_amount:BigDecimal.new("1.21"), first_sale:true, contract_amount:BigDecimal.new("46.46"), non_dutiable_amount:BigDecimal.new("7.63")
      inv_1_line_first_sale_tar = inv_1_line_first_sale.commercial_invoice_tariffs.create! hts_code:"356790123", duty_rate:BigDecimal.new(".667"), entered_value:44
      # Should be excluded because of no non-dutiable amount (ocean entry).
      inv_line_no_non_dutiable = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:12, value:BigDecimal.new("20.20"), part_number:"part-A", entered_value_7501: 33, container:cont_1, add_to_make_amount:BigDecimal.new("0.20"), countract_amount:BigDecimal.new("44.44"), first_sale:false, non_dutiable_amount:BigDecimal.new("0")
      inv_line_nil_non_dutiable = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:13, value:BigDecimal.new("20.20"), part_number:"part-A", entered_value_7501: 33, container:cont_1, add_to_make_amount:BigDecimal.new("0.20"), countract_amount:BigDecimal.new("44.44"), first_sale:false, non_dutiable_amount:nil

      factory_1 = Factory(:factory, name:"factory-1")
      ord_1 = Factory(:order, importer_id:pvh.id, order_number:"PVH-PO-A", factory_id:factory_1.id)
      ord_1_line_1 = ord_1.order_lines.create! line_number:1, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("5.67")
      ord_1_line_2 = ord_1.order_lines.create! line_number:3, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("6.78")

      shipments = double("shipments")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("10", ["A","B"], ["C","D"], force_lookup:true).and_return(shipments)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).twice.with("10", "LCL").and_return(true)
      shipment_line_1 = double("shipment_line_1")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, "cont-1", "PO-A", "part-A", 10, invoice_number:"inv-1").and_return(shipment_line_1)
      expect(shipment_line_1).to receive(:order_line).and_return(ord_1_line_1)
      shipment_line_2 = double("shipment_line_2")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, "cont-1", "PO-A", "part-B", 11, invoice_number:"inv-1").and_return(shipment_line_2)
      expect(shipment_line_2).to receive(:order_line).and_return(ord_1_line_2)

      entry_2 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-2", arrival_date:Date.new(2019,1,12), fiscal_date:Date.new(2019,1,14), transport_mode_code:'11', master_bills_of_lading:'C', house_bills_of_lading:'D', fcl_lcl:'FCL')
      inv_2 = entry_2.commercial_invoices.create! invoice_number:"inv-2"
      cont_2 = Container.create! container_number: "cont-2"
      inv_2_line = inv_2.commercial_invoice_lines.create! po_number:"PO-C", quantity:12, value:BigDecimal.new("72.22"), entered_value_7501:35, part_number:"part-C", container:cont_2, add_to_make_amount:BigDecimal.new("3.23"), contract_amount:BigDecimal.new("47.47"), non_dutiable_amount:BigDecimal.new("8.76")
      inv_2_line_tar = inv_2_line.commercial_invoice_tariffs.create! hts_code:"567901234", duty_rate:BigDecimal.new(".5"), entered_value:35

      factory_2 = Factory(:factory, name:"factory-2")
      ord_2 = Factory(:order, importer_id:pvh.id, order_number:"PVH-PO-C", factory_id:factory_2.id)
      ord_2_line = ord_2.order_lines.create! line_number:5, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("7.89")

      shipments_2 = double("shipments_2")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("11", ["C"], ["D"], force_lookup:true).and_return(shipments_2)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("11", "FCL").and_return(false)
      shipment_line_3 = double("shipment_line_3")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments_2, "cont-2", "PO-C", "part-C", 12, invoice_number:nil).and_return(shipment_line_3)
      expect(shipment_line_3).to receive(:order_line).and_return(ord_2_line)

      # These should be excluded based on date.
      entry_not_pvh = Factory(:entry, customer_number:"NOT PVH", entry_number:"entry-3", fiscal_date:Date.new(2018,12,25), transport_mode_code:'10')
      entry_too_old = Factory(:entry, customer_number:"PVH", entry_number:"entry-4", fiscal_date:Date.new(2018,12,14), transport_mode_code:'10')
      entry_too_new = Factory(:entry, customer_number:"PVH", entry_number:"entry-5", fiscal_date:Date.new(2019,1,15), transport_mode_code:'10')

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVH_Duty_Discount_US_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 9
      expect(detail_sheet[0]).to eq ["Customs Entry Number", "Vendor Invoice Number", "PO Number", "Shipment Number", "PO Line", "HTS Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Dutiable Value", "Duty Adj Amount", "Duty Savings", "Duty Rate PCT", "First Cost - PO", "Units Shipped", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "235679012", Date.new(2018,12,13), 40.2, 2.22, 33.0, -9.42, 3.14, 33.3, 5.67, 10.0, "SEA"]
      expect(detail_sheet[2]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "235679015", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 0.19, 2.0, 5.67, 10.0, "SEA"]
      expect(detail_sheet[3]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "990279014", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 0.94, 10.0, 5.67, 10.0, "SEA"]
      expect(detail_sheet[4]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "990379013", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 2.36, 25.0, 5.67, 10.0, "SEA"]
      expect(detail_sheet[5]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 3, "356790123", Date.new(2018,12,13), 51.21, 1.21, 44.0, -8.42, 5.62, 66.7, 6.78, 11.0, "SEA"]
      expect(detail_sheet[6]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, 91.41, 3.43, 77.0, -17.84, 12.25, nil, nil, nil, "SEA"]
      expect(detail_sheet[7]).to eq ["entry-2", "inv-2", "PO-C", "cont-2", 5, "567901234", Date.new(2019,1,12), 72.22, 3.23, 35.0, -40.45, 20.23, 50.0, 7.89, 12.0, "SEA"]
      expect(detail_sheet[8]).to eq ["entry-2", nil, nil, nil, nil, nil, nil, 72.22, 3.23, 35.0, -40.45, 20.23, nil, nil, nil, "SEA"]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 6
      expect(summary_sheet[0]).to eq ["Customs Entry Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Duty Adj Amount", "Dutiable Value", "Duty Difference", "Duty Savings", "Mode of Transport"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2018,12,13), 91.41, 3.43, -17.84, 77.0, 17.84, 12.25, "SEA"]
      expect(summary_sheet[2]).to eq ["entry-2", Date.new(2019,1,12), 72.22, 3.23, -40.45, 35.0, 40.45, 20.23, "SEA"]
      expect(summary_sheet[3]).to eq ["Grand Totals", nil, "SUBTOTAL(9, C2:C3)", "SUBTOTAL(9, D2:D3)", "SUBTOTAL(9, E2:E3)", "SUBTOTAL(9, F2:F3)", "SUBTOTAL(9, G2:G3)", "SUBTOTAL(9, H2:H3)", nil]
      expect(summary_sheet[4]).to eq ["Total Entries (SEA)", "COUNTIF(I2:I3, \"SEA\")"]
      expect(summary_sheet[5]).to eq ["Total Entries (AIR)", "COUNTIF(I2:I3, \"AIR\")"]
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end

    def make_eastern_date year, month, day
      dt = make_utc_date(year, month, day)
      dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
      dt
    end

    it "defaults years when not provided" do
      fiscal_month_previous = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:9, start_date:Date.new(2019,8,15), end_date:Date.new(2019,9,14))
      fiscal_month_current = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:10, start_date:Date.new(2019,9,15), end_date:Date.new(2019,10,14))

      entry = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", arrival_date:Date.new(2019,8,13), fiscal_date:Date.new(2019,8,22), transport_mode_code:'40', master_bills_of_lading:'MBOL_X')
      inv = entry.commercial_invoices.create! invoice_number:"inv-1"
      cont = Container.create! container_number: "cont-1"
      inv_line = inv.commercial_invoice_lines.create! po_number:"PO-A", quantity:10, value:BigDecimal.new("20.20"), part_number:"part-A", entered_value_7501: 33, container:cont, add_to_make_amount:BigDecimal.new("0.20"), countract_amount:BigDecimal.new("44.44"), freight_amount:BigDecimal.new("7.65")
      inv_line_tar = inv_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value:33
      # Should be excluded because of no freight amount (air entry).
      inv_line_no_freight = inv.commercial_invoice_lines.create! po_number:"PO-A", quantity:11, value:BigDecimal.new("20.20"), part_number:"part-A", entered_value_7501: 33, container:cont, add_to_make_amount:BigDecimal.new("0.20"), countract_amount:BigDecimal.new("44.44"), freight_amount:BigDecimal.new("0")
      inv_line_nil_freight = inv.commercial_invoice_lines.create! po_number:"PO-A", quantity:12, value:BigDecimal.new("20.20"), part_number:"part-A", entered_value_7501: 33, container:cont, add_to_make_amount:BigDecimal.new("0.20"), countract_amount:BigDecimal.new("44.44"), freight_amount:nil

      factory = Factory(:factory, name:"factory-1")
      ord = Factory(:order, importer_id:pvh.id, order_number:"PVH-PO-A", factory_id:factory.id)

      expect_any_instance_of(described_class).to receive(:get_po_line_values).and_return([14, BigDecimal.new("5.67")])

      # These should be excluded based on date.
      entry_too_old = Factory(:entry, customer_number:"PVH", entry_number:"entry-4", fiscal_date:Date.new(2019,8,14), transport_mode_code:'40')
      entry_too_new = Factory(:entry, customer_number:"PVH", entry_number:"entry-5", fiscal_date:Date.new(2019,9,16), transport_mode_code:'40')

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {})
      end
      expect(@temp.original_filename).to eq "PVH_Duty_Discount_US_Fiscal_2019-09_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 3
      expect(detail_sheet[0]).to eq ["Customs Entry Number", "Vendor Invoice Number", "PO Number", "Shipment Number", "PO Line", "HTS Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Dutiable Value", "Duty Adj Amount", "Duty Savings", "Duty Rate PCT", "First Cost - PO", "Units Shipped", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", "MBOL_X", 14, "235679012", Date.new(2019,8,13), 20.2, 0.2, 33, 12.6, 4.2, 33.3, 5.67, 10.0, "AIR"]
      expect(detail_sheet[2]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, 20.2, 0.2, 33.0, 12.6, 4.2, nil, nil, nil, "AIR"]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 5
      expect(summary_sheet[0]).to eq ["Customs Entry Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Duty Adj Amount", "Dutiable Value", "Duty Difference", "Duty Savings", "Mode of Transport"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2019,8,13), 20.2, 0.2, 12.6, 33.0, -12.6, 4.2, "AIR"]
      expect(summary_sheet[2]).to eq ["Grand Totals", nil, "SUBTOTAL(9, C2:C2)", "SUBTOTAL(9, D2:D2)", "SUBTOTAL(9, E2:E2)", "SUBTOTAL(9, F2:F2)", "SUBTOTAL(9, G2:G2)", "SUBTOTAL(9, H2:H2)", nil]
      expect(summary_sheet[3]).to eq ["Total Entries (SEA)", "COUNTIF(I2:I2, \"SEA\")"]
      expect(summary_sheet[4]).to eq ["Total Entries (AIR)", "COUNTIF(I2:I2, \"AIR\")"]
    end

    it "generates spreadsheet for the current fiscal quarter" do
      fiscal_month_previous_1 = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:7, start_date:Date.new(2019,6,15), end_date:Date.new(2019,7,14))
      fiscal_month_previous_2 = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:8, start_date:Date.new(2019,7,15), end_date:Date.new(2019,8,14))
      fiscal_month_previous_3 = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:9, start_date:Date.new(2019,8,15), end_date:Date.new(2019,9,14))
      fiscal_month_current = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:10, start_date:Date.new(2019,9,15), end_date:Date.new(2019,10,14))

      entry_1 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", arrival_date:Date.new(2018,12,13), fiscal_date:Date.new(2019,6,16), transport_mode_code:'10', master_bills_of_lading:"A\nB", house_bills_of_lading:"C\nD", fcl_lcl:'LCL')
      inv_1 = entry_1.commercial_invoices.create! invoice_number:"inv-1"
      cont_1 = Container.create! container_number: "cont-1"
      inv_1_line_1 = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:10, contract_amount:BigDecimal.new("40.20"), entered_value_7501: 33, part_number:"part-A", container:cont_1, add_to_make_amount:BigDecimal.new("2.22"), non_dutiable_amount:BigDecimal.new("7.65")
      inv_1_line_1_tar_1 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value:nil
      inv_1_line_1_tar_2 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"990379013", duty_rate:BigDecimal.new(".25"), entered_value:22, special_tariff:true
      inv_1_line_1_tar_3 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"990279014", duty_rate:BigDecimal.new(".10"), entered_value:11, special_tariff:true
      inv_1_line_1_tar_4 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679015", duty_rate:BigDecimal.new(".02"), entered_value:nil
      inv_1_line_2 = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:11, contract_amount:BigDecimal.new("51.21"), entered_value_7501:44, part_number:"part-B", container:cont_1, add_to_make_amount:BigDecimal.new("1.21"), non_dutiable_amount:BigDecimal.new("6.75")
      inv_1_line_2_tar = inv_1_line_2.commercial_invoice_tariffs.create! hts_code:"356790123", duty_rate:BigDecimal.new(".667"), entered_value:44

      factory_1 = Factory(:factory, name:"factory-1")
      ord_1 = Factory(:order, importer_id:pvh.id, order_number:"PVH-PO-A", factory_id:factory_1.id)
      ord_1_line_1 = ord_1.order_lines.create! line_number:1, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("5.67")
      ord_1_line_2 = ord_1.order_lines.create! line_number:3, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("6.78")

      shipments = double("shipments")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("10", ["A","B"], ["C","D"], force_lookup:true).and_return(shipments)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).twice.with("10", "LCL").and_return(true)
      shipment_line_1 = double("shipment_line_1")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, "cont-1", "PO-A", "part-A", 10, invoice_number:"inv-1").and_return(shipment_line_1)
      expect(shipment_line_1).to receive(:order_line).and_return(ord_1_line_1)
      shipment_line_2 = double("shipment_line_2")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, "cont-1", "PO-A", "part-B", 11, invoice_number:"inv-1").and_return(shipment_line_2)
      expect(shipment_line_2).to receive(:order_line).and_return(ord_1_line_2)

      entry_2 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-2", arrival_date:Date.new(2019,1,12), fiscal_date:Date.new(2019,9,13), transport_mode_code:'11', master_bills_of_lading:'C', house_bills_of_lading:'D', fcl_lcl:'FCL')
      inv_2 = entry_2.commercial_invoices.create! invoice_number:"inv-2"
      cont_2 = Container.create! container_number: "cont-2"
      inv_2_line = inv_2.commercial_invoice_lines.create! po_number:"PO-C", quantity:12, contract_amount:BigDecimal.new("72.22"), entered_value_7501:35, part_number:"part-C", container:cont_2, add_to_make_amount:BigDecimal.new("3.23"), non_dutiable_amount:BigDecimal.new("5.76")
      inv_2_line_tar = inv_2_line.commercial_invoice_tariffs.create! hts_code:"567901234", duty_rate:BigDecimal.new(".5"), entered_value:35

      factory_2 = Factory(:factory, name:"factory-2")
      ord_2 = Factory(:order, importer_id:pvh.id, order_number:"PVH-PO-C", factory_id:factory_2.id)
      ord_2_line = ord_2.order_lines.create! line_number:5, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("7.89")

      shipments_2 = double("shipments_2")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("11", ["C"], ["D"], force_lookup:true).and_return(shipments_2)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("11", "FCL").and_return(false)
      shipment_line_3 = double("shipment_line_3")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments_2, "cont-2", "PO-C", "part-C", 12, invoice_number:nil).and_return(shipment_line_3)
      expect(shipment_line_3).to receive(:order_line).and_return(ord_2_line)

      # These should be excluded based on date.
      entry_too_old = Factory(:entry, customer_number:"PVH", entry_number:"entry-4", fiscal_date:Date.new(2019,6,13), transport_mode_code:'10')
      entry_too_new = Factory(:entry, customer_number:"PVH", entry_number:"entry-5", fiscal_date:Date.new(2019,9,15), transport_mode_code:'10')

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'quarterly'=>'true'})
      end
      expect(@temp.original_filename).to eq "PVH_Duty_Discount_US_Fiscal_2019-Quarter-3_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 9
      expect(detail_sheet[0]).to eq ["Customs Entry Number", "Vendor Invoice Number", "PO Number", "Shipment Number", "PO Line", "HTS Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Dutiable Value", "Duty Adj Amount", "Duty Savings", "Duty Rate PCT", "First Cost - PO", "Units Shipped", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "235679012", Date.new(2018,12,13), 0.0, 2.22, 33, 30.78, 10.25, 33.3, 5.67, 10.0, "SEA"]
      expect(detail_sheet[2]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "235679015", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 0.62, 2.0, 5.67, 10.0, "SEA"]
      expect(detail_sheet[3]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "990279014", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 3.08, 10.0, 5.67, 10.0, "SEA"]
      expect(detail_sheet[4]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, "990379013", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 7.7, 25.0, 5.67, 10.0, "SEA"]
      expect(detail_sheet[5]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 3, "356790123", Date.new(2018,12,13), 0.0, 1.21, 44, 42.79, 28.54, 66.7, 6.78, 11.0, "SEA"]
      expect(detail_sheet[6]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, 0.0, 3.43, 77.0, 73.57, 50.19, nil, nil, nil, "SEA"]
      expect(detail_sheet[7]).to eq ["entry-2", "inv-2", "PO-C", "cont-2", 5, "567901234", Date.new(2019,1,12), 0.0, 3.23, 35, 31.77, 15.89, 50.0, 7.89, 12.0, "SEA"]
      expect(detail_sheet[8]).to eq ["entry-2", nil, nil, nil, nil, nil, nil, 0.0, 3.23, 35.0, 31.77, 15.89, nil, nil, nil, "SEA"]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 6
      expect(summary_sheet[0]).to eq ["Customs Entry Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Duty Adj Amount", "Dutiable Value", "Duty Difference", "Duty Savings", "Mode of Transport"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2018,12,13), 0.0, 3.43, 73.57, 77.0, -73.57, 50.19, "SEA"]
      expect(summary_sheet[2]).to eq ["entry-2", Date.new(2019,1,12), 0.0, 3.23, 31.77, 35.0, -31.77, 15.89, "SEA"]
      expect(summary_sheet[3]).to eq ["Grand Totals", nil, "SUBTOTAL(9, C2:C3)", "SUBTOTAL(9, D2:D3)", "SUBTOTAL(9, E2:E3)", "SUBTOTAL(9, F2:F3)", "SUBTOTAL(9, G2:G3)", "SUBTOTAL(9, H2:H3)", nil]
      expect(summary_sheet[4]).to eq ["Total Entries (SEA)", "COUNTIF(I2:I3, \"SEA\")"]
      expect(summary_sheet[5]).to eq ["Total Entries (AIR)", "COUNTIF(I2:I3, \"AIR\")"]
    end

    it "errors when provided fiscal month does not exist" do
      expect { described_class.run_report(u, {'fiscal_month'=>'2019-01'}) }.to raise_error("Fiscal month 2019-01 not found.")
    end

    it "errors when provided fiscal month is invalid" do
      expect { described_class.run_report(u, {'fiscal_month'=>'invalid'}) }.to raise_error("Fiscal month invalid not found.")
    end

    it "errors when defaulting fiscal month and the previous month cannot be found" do
      fiscal_month_current = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:10, start_date:Date.new(2019,9,15), end_date:Date.new(2019,10,14))

      expect do
        Timecop.freeze(make_eastern_date(2019,9,30)) do
          described_class.run_report(u, {})
        end
      end.to raise_error("Fiscal month to use could not be determined.")
    end

    it "errors when defaulting fiscal month and the current month cannot be found" do
      expect do
        Timecop.freeze(make_eastern_date(2019,9,30)) do
          described_class.run_report(u, {})
        end
      end.to raise_error("Fiscal month to use could not be determined.")
    end

    it "errors when quarterly and previous quarter cannot be determined" do
      # There is a month 3 of the previous quarter, but no month 1.
      fiscal_month_previous_final = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:9, start_date:Date.new(2019,8,15), end_date:Date.new(2019,9,14))
      fiscal_month_current = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:10, start_date:Date.new(2019,9,15), end_date:Date.new(2019,10,14))

      expect do
        Timecop.freeze(make_eastern_date(2019,9,30)) do
          described_class.run_report(u, {'quarterly'=>'true'})
        end
      end.to raise_error("Quarter boundaries could not be determined.")
    end

    it "errors when PVH company is not found" do
      pvh.destroy!

      expect { described_class.run_report(u, {}) }.to raise_error("PVH company account could not be found.")
    end

    it "appropriately handles null number values and absent order/factory content" do
      fiscal_month = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:1, start_date:Date.new(2018,12,15), end_date:Date.new(2019,1,14))

      entry = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", arrival_date:Date.new(2018,12,13), fiscal_date:Date.new(2018,12,22), transport_mode_code:"10")
      inv = entry.commercial_invoices.create! invoice_number:"inv-1"
      cont = Container.create! container_number: "cont-1"
      inv_line = inv.commercial_invoice_lines.create! po_number:"PO-A", quantity:nil, contract_amount:nil, part_number:"part-A", container:cont, add_to_make_amount:nil, non_dutiable_amount:BigDecimal.new("20.20"), value:nil
      inv_line_tar = inv_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:nil, entered_value:nil

      expect_any_instance_of(described_class).to receive(:get_po_line_values).and_return([nil, nil])

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVH_Duty_Discount_US_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 3
      expect(detail_sheet[0]).to eq ["Customs Entry Number", "Vendor Invoice Number", "PO Number", "Shipment Number", "PO Line", "HTS Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Dutiable Value", "Duty Adj Amount", "Duty Savings", "Duty Rate PCT", "First Cost - PO", "Units Shipped", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", nil, "235679012", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, nil, "SEA"]
      expect(detail_sheet[2]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, 0.0, 0.0, 0.0, 0.0, 0.0, nil, nil, nil, "SEA"]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 5
      expect(summary_sheet[0]).to eq ["Customs Entry Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Duty Adj Amount", "Dutiable Value", "Duty Difference", "Duty Savings", "Mode of Transport"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "SEA"]
      expect(summary_sheet[2]).to eq ["Grand Totals", nil, "SUBTOTAL(9, C2:C2)", "SUBTOTAL(9, D2:D2)", "SUBTOTAL(9, E2:E2)", "SUBTOTAL(9, F2:F2)", "SUBTOTAL(9, G2:G2)", "SUBTOTAL(9, H2:H2)", nil]
      expect(summary_sheet[3]).to eq ["Total Entries (SEA)", "COUNTIF(I2:I2, \"SEA\")"]
      expect(summary_sheet[4]).to eq ["Total Entries (AIR)", "COUNTIF(I2:I2, \"AIR\")"]
    end

    it "handles zero lines" do
      fiscal_month = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:1, start_date:Date.new(2018,12,15), end_date:Date.new(2019,1,14))

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVH_Duty_Discount_US_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 1
      expect(detail_sheet[0]).to eq ["Customs Entry Number", "Vendor Invoice Number", "PO Number", "Shipment Number", "PO Line", "HTS Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Dutiable Value", "Duty Adj Amount", "Duty Savings", "Duty Rate PCT", "First Cost - PO", "Units Shipped", "Mode of Transport"]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 4
      expect(summary_sheet[0]).to eq ["Customs Entry Number", "ETA", "Vendor Invoice Value", "Duty Assist Amount", "Duty Adj Amount", "Dutiable Value", "Duty Difference", "Duty Savings", "Mode of Transport"]
      expect(summary_sheet[1]).to eq ["Grand Totals", nil, 0, 0, 0, 0, 0, 0, nil]
      expect(summary_sheet[2]).to eq ["Total Entries (SEA)", 0]
      expect(summary_sheet[3]).to eq ["Total Entries (AIR)", 0]
    end

  end

  describe "run_schedulable" do
    it "calls run report method if configured day of fiscal month" do
      settings = {'email' => 'a@b.com'}
      current_fiscal_month = double("current fiscal month")
      expect(described_class).to receive(:run_if_configured).with(settings).and_yield(current_fiscal_month, double("fiscal date"))
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_duty_discount_report).with(settings, current_fiscal_month:current_fiscal_month).and_return "success"

      expect(described_class.run_schedulable(settings)).to eq("success")
    end

    it "does not call run report method if wrong day of fiscal month" do
      settings = {'email' => 'a@b.com'}
      # Does not yield.
      expect(described_class).to receive(:run_if_configured).with(settings)
      expect(subject).to_not receive(:run_duty_discount_report)

      expect(described_class.run_schedulable(settings)).to be_nil
    end

    it "raises an exception if blank email param is provided" do
      expect(described_class).not_to receive(:new)

      expect { described_class.run_schedulable({'email' => ' '}) }.to raise_error("Email address is required.")
    end

    it "raises an exception if no email param is provided" do
      expect(described_class).not_to receive(:new)

      expect { described_class.run_schedulable({}) }.to raise_error("Email address is required.")
    end
  end

end
