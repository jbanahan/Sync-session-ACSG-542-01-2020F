describe OpenChain::Report::PvhFirstCostSavingsReport do

  describe "permission?" do
    let(:ms) { stub_master_setup }
    let (:u) { Factory(:user) }
    let (:group) { Group.use_system_group 'pvh_first_cost_savings_report', create: true }

    it "allows access for users who can view entries, are subscribed to report custom feature and are in group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH First Cost Savings Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by users who cannot view entries" do
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not subscribed to report custom feature" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH First Cost Savings Report").and_return false
      expect(described_class.permission? u).to eq false
    end

    it "prevents access by users who are not in the group" do
      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH First Cost Savings Report").and_return true
      expect(u).to receive(:in_group?).with(group).and_return false
      expect(described_class.permission? u).to eq false
    end

    it "creates group if it does not already exist" do
      group.destroy!

      expect(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("PVH First Cost Savings Report").and_return true
      expect(u).to receive(:in_group?).and_return false
      expect(described_class.permission? u).to eq false

      group = Group.where(system_code:"pvh_first_cost_savings_report").first
      expect(group).to_not be_nil
      expect(group.name).to eq "PVH First Cost Savings Report"
      expect(group.description).to eq "Users able to run the PVH First Cost Savings Report."
    end
  end

  describe "run_report" do
    let (:u) { Factory(:user) }
    let!(:pvh) { Factory(:company, name:'PVH Importer', system_code:'PVH') }

    after { @temp.close if @temp }

    it "generates spreadsheet" do
      fiscal_month = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:1, start_date:Date.new(2018,12,15), end_date:Date.new(2019,1,14))

      entry_1 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", transport_mode_code:"10", fiscal_date:Date.new(2018,12,15), master_bills_of_lading:"A\nB", house_bills_of_lading:"C\nD", fcl_lcl:'LCL', release_date:Date.new(2018,12,25))
      inv_1 = entry_1.commercial_invoices.create! invoice_number:"inv-1", master_bills_of_lading:"mbol-1"
      cont_1 = Container.create! container_number: "cont-1"
      inv_1_line_1 = inv_1.commercial_invoice_lines.create! vendor_name:"Vendco", po_number:"PO-A", quantity:10, country_origin_code:"CN", contract_amount:BigDecimal.new("40.20"), part_number:"part-A", container:cont_1, first_sale:true
      inv_1_line_1_tar_1 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value_7501:nil
      inv_1_line_1_tar_2 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"990379013", duty_rate:BigDecimal.new(".25"), entered_value_7501:22, special_tariff:true
      inv_1_line_1_tar_3 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"990279014", duty_rate:BigDecimal.new(".10"), entered_value_7501:11, special_tariff:true
      inv_1_line_1_tar_4 = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679015", duty_rate:BigDecimal.new(".02"), entered_value_7501:nil
      inv_1_line_2 = inv_1.commercial_invoice_lines.create! vendor_name:"Vendco", po_number:"PO-A", quantity:11, country_origin_code:"CN", contract_amount:BigDecimal.new("51.21"), part_number:"part-B", container:cont_1, first_sale:true
      inv_1_line_2_tar = inv_1_line_2.commercial_invoice_tariffs.create! hts_code:"356790123", duty_rate:BigDecimal.new(".667"), entered_value_7501:44
      # This line should be left off because it's not a first sale.
      inv_1_line_not_first_sale = inv_1.commercial_invoice_lines.create! vendor_name:"Vendco", po_number:"PO-A", quantity:12, country_origin_code:"CN", contract_amount:BigDecimal.new("63.77"), part_number:"part-B", container:cont_1, first_sale:false

      factory_1 = Factory(:factory, name:"factory-1")
      ord_1 = Factory(:order, importer_id:pvh.id, order_number:"pvh-PO-A", factory_id:factory_1.id)
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

      entry_2 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-2", transport_mode_code:"40", fiscal_date:Date.new(2019,1,14), master_bills_of_lading:'C', house_bills_of_lading:'D', fcl_lcl:'FCL', release_date:Date.new(2019,1,15))
      inv_2 = entry_2.commercial_invoices.create! invoice_number:"inv-2", master_bills_of_lading:"mbol-2"
      cont_2 = Container.create! container_number: "cont-2"
      inv_2_line = inv_2.commercial_invoice_lines.create! vendor_name:"Vendco-2", po_number:"PO-C", quantity:12, country_origin_code:"IN", contract_amount:BigDecimal.new("72.22"), part_number:"part-C", container:cont_2, first_sale:true
      inv_2_line_tar = inv_2_line.commercial_invoice_tariffs.create! hts_code:"567901234", duty_rate:BigDecimal.new(".5"), entered_value_7501:35

      factory_2 = Factory(:factory, name:"factory-2")
      ord_2 = Factory(:order, importer_id:pvh.id, order_number:"pvh-PO-C", factory_id:factory_2.id)
      ord_2_line = ord_2.order_lines.create! line_number:5, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("7.89")

      shipments_2 = double("shipments_2")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("40", ["C"], ["D"], force_lookup:true).and_return(shipments_2)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("40", "FCL").and_return(false)
      shipment_line_3 = double("shipment_line_3")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments_2, "cont-2", "PO-C", "part-C", 12, invoice_number:nil).and_return(shipment_line_3)
      expect(shipment_line_3).to receive(:order_line).and_return(ord_2_line)

      # These should be excluded.
      entry_not_pvh = Factory(:entry, customer_number:"NOT PVH", entry_number:"entry-3", fiscal_date:Date.new(2018,12,25))
      entry_too_old = Factory(:entry, customer_number:"PVH", entry_number:"entry-4", fiscal_date:Date.new(2018,12,14))
      entry_too_new = Factory(:entry, customer_number:"PVH", entry_number:"entry-5", fiscal_date:Date.new(2019,1,15))

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVH_Cost_Savings_for_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 7
      expect(detail_sheet[0]).to eq ["Entry Number", "Customs Entry Date", "Vendor Name", "Factory Name", "PO Number", "PO Line Number", "Shipment", "Unit Cost (PO)", "Units Shipped", "Origin", "Invoice Number", "HTS Code", "Duty Rate PCT", "Vendor Invoice Value", "Customs Value", "Difference", "Savings", "% Difference"]
      expect(detail_sheet[1]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 1, "cont-1", 5.67, 10.0, "CN", "inv-1", "235679012", 33.3, 40.2, 33, 7.2, 2.4, 17.91]
      expect(detail_sheet[2]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 1, "cont-1", 5.67, 10.0, "CN", "inv-1", "235679015", 2.0, 0.0, 0.0, 0.0, 0.14, 0.0]
      expect(detail_sheet[3]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 1, "cont-1", 5.67, 10.0, "CN", "inv-1", "990279014", 10.00, 0.0, 0.0, 0.0, 0.72, 0.0]
      expect(detail_sheet[4]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 1, "cont-1", 5.67, 10.0, "CN", "inv-1", "990379013", 25.0, 0.0, 0.0, 0.0, 1.8, 0.0]
      expect(detail_sheet[5]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 3, "cont-1", 6.78, 11.0, "CN", "inv-1", "356790123", 66.7, 51.21, 44, 7.21, 4.81, 14.08]
      expect(detail_sheet[6]).to eq ["entry-2", Date.new(2019,1,15), "Vendco-2", "factory-2", "PO-C", 5, "C", 7.89, 12.0, "IN", "inv-2", "567901234", 50.0, 72.22, 35, 37.22, 18.61, 51.54]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 3
      expect(summary_sheet[0]).to eq ["Vendor Name", "Factory Name", "Origin", "Co", "Entry Number", "Vendor Invoice Value", "Customs Value", "Difference", "Savings"]
      expect(summary_sheet[1]).to eq ["Vendco", "factory-1", "CN", "PO", "entry-1", 91.41, 77.0, 14.41, 9.87]
      expect(summary_sheet[2]).to eq ["Vendco-2", "factory-2", "IN", "PO", "entry-2", 72.22, 35, 37.22, 18.61]
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

      entry = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", transport_mode_code:"10", fiscal_date:Date.new(2019,8,22), release_date:Date.new(2018,12,25))
      inv = entry.commercial_invoices.create! invoice_number:"inv-1", master_bills_of_lading:"mbol-1"
      cont = Container.create! container_number: "cont-1"
      inv_line = inv.commercial_invoice_lines.create! vendor_name:"Vendco", po_number:"PO-A", quantity:10, country_origin_code:"CN", contract_amount:BigDecimal.new("20.20"), part_number:"part-A", container:cont, first_sale:true
      inv_line_tar = inv_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value_7501:33

      factory = Factory(:factory, name:"factory-1")
      ord = Factory(:order, importer_id:pvh.id, order_number:"pvh-PO-A", factory_id:factory.id)

      expect_any_instance_of(described_class).to receive(:get_po_line_values).and_return([14, BigDecimal.new("5.67")])

      # These should be excluded.
      entry_too_old = Factory(:entry, customer_number:"PVH", entry_number:"entry-4", fiscal_date:Date.new(2019,8,14))
      entry_too_new = Factory(:entry, customer_number:"PVH", entry_number:"entry-5", fiscal_date:Date.new(2019,9,15))

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {})
      end
      expect(@temp.original_filename).to eq "PVH_Cost_Savings_for_Fiscal_2019-09_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 2
      expect(detail_sheet[0]).to eq ["Entry Number", "Customs Entry Date", "Vendor Name", "Factory Name", "PO Number", "PO Line Number", "Shipment", "Unit Cost (PO)", "Units Shipped", "Origin", "Invoice Number", "HTS Code", "Duty Rate PCT", "Vendor Invoice Value", "Customs Value", "Difference", "Savings", "% Difference"]
      expect(detail_sheet[1]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 14, "cont-1", 5.67, 10.0, "CN", "inv-1", "235679012", 33.3, 20.2, 33, -12.8, -4.26, -63.37]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 2
      expect(summary_sheet[0]).to eq ["Vendor Name", "Factory Name", "Origin", "Co", "Entry Number", "Vendor Invoice Value", "Customs Value", "Difference", "Savings"]
      expect(summary_sheet[1]).to eq ["Vendco", "factory-1", "CN", "PO", "entry-1", 20.2, 33, -12.8, -4.26]
    end

    it "generates spreadsheet for the current fiscal quarter" do
      fiscal_month_previous_1 = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:7, start_date:Date.new(2019,6,15), end_date:Date.new(2019,7,14))
      fiscal_month_previous_2 = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:8, start_date:Date.new(2019,7,15), end_date:Date.new(2019,8,14))
      fiscal_month_previous_3 = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:9, start_date:Date.new(2019,8,15), end_date:Date.new(2019,9,14))
      fiscal_month_current = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:10, start_date:Date.new(2019,9,15), end_date:Date.new(2019,10,14))

      entry_1 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", transport_mode_code:"10", fiscal_date:Date.new(2019,6,16), master_bills_of_lading:"A\nB", house_bills_of_lading:"C\nD", fcl_lcl:'LCL', release_date:Date.new(2018,12,25))
      inv_1 = entry_1.commercial_invoices.create! invoice_number:"inv-1", master_bills_of_lading:"mbol-1"
      cont_1 = Container.create! container_number: "cont-1"
      inv_1_line = inv_1.commercial_invoice_lines.create! vendor_name:"Vendco", po_number:"PO-A", quantity:10, country_origin_code:"CN", contract_amount:BigDecimal.new("40.20"), part_number:"part-A", container:cont_1, first_sale:true
      inv_1_line_tar = inv_1_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value_7501:9

      factory_1 = Factory(:factory, name:"factory-1")
      ord_1 = Factory(:order, importer_id:pvh.id, order_number:"pvh-PO-A", factory_id:factory_1.id)
      ord_1_line = ord_1.order_lines.create! line_number:1, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("5.67")

      shipments = double("shipments")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("10", ["A","B"], ["C","D"], force_lookup:true).and_return(shipments)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("10", "LCL").and_return(true)
      shipment_line_1 = double("shipment_line_1")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, "cont-1", "PO-A", "part-A", 10, invoice_number:"inv-1").and_return(shipment_line_1)
      expect(shipment_line_1).to receive(:order_line).and_return(ord_1_line)

      entry_2 = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-2", transport_mode_code:"40", fiscal_date:Date.new(2019,9,13), master_bills_of_lading:'C', house_bills_of_lading:'D', fcl_lcl:'FCL', release_date:Date.new(2019,1,15))
      inv_2 = entry_2.commercial_invoices.create! invoice_number:"inv-2", master_bills_of_lading:"mbol-2"
      cont_2 = Container.create! container_number: "cont-2"
      inv_2_line = inv_2.commercial_invoice_lines.create! vendor_name:"Vendco-2", po_number:"PO-C", quantity:12, country_origin_code:"IN", contract_amount:BigDecimal.new("72.22"), part_number:"part-C", container:cont_2, first_sale:true
      inv_2_line_tar = inv_2_line.commercial_invoice_tariffs.create! hts_code:"567901234", duty_rate:BigDecimal.new(".5"), entered_value_7501:35

      factory_2 = Factory(:factory, name:"factory-2")
      ord_2 = Factory(:order, importer_id:pvh.id, order_number:"pvh-PO-C", factory_id:factory_2.id)
      ord_2_line = ord_2.order_lines.create! line_number:5, product_id:Factory(:product, importer_id:pvh.id).id, price_per_unit:BigDecimal.new("7.89")

      shipments_2 = double("shipments_2")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("40", ["C"], ["D"], force_lookup:true).and_return(shipments_2)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("40", "FCL").and_return(false)
      shipment_line_3 = double("shipment_line_3")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments_2, "cont-2", "PO-C", "part-C", 12, invoice_number:nil).and_return(shipment_line_3)
      expect(shipment_line_3).to receive(:order_line).and_return(ord_2_line)

      # These should be excluded.
      entry_too_old = Factory(:entry, customer_number:"PVH", entry_number:"entry-3", fiscal_date:Date.new(2019,6,13))
      entry_too_new = Factory(:entry, customer_number:"PVH", entry_number:"entry-4", fiscal_date:Date.new(2019,9,15))

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'quarterly'=>'true'})
      end
      expect(@temp.original_filename).to eq "PVH_Cost_Savings_for_Fiscal_2019-Quarter-3_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 3
      expect(detail_sheet[0]).to eq ["Entry Number", "Customs Entry Date", "Vendor Name", "Factory Name", "PO Number", "PO Line Number", "Shipment", "Unit Cost (PO)", "Units Shipped", "Origin", "Invoice Number", "HTS Code", "Duty Rate PCT", "Vendor Invoice Value", "Customs Value", "Difference", "Savings", "% Difference"]
      expect(detail_sheet[1]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", "factory-1", "PO-A", 1, "cont-1", 5.67, 10.0, "CN", "inv-1", "235679012", 33.3, 40.2, 9.0, 31.2, 10.39, 77.61]
      expect(detail_sheet[2]).to eq ["entry-2", Date.new(2019,1,15),  "Vendco-2", "factory-2", "PO-C", 5, "C", 7.89, 12.0, "IN", "inv-2", "567901234", 50.0, 72.22, 35, 37.22, 18.61, 51.54]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 3
      expect(summary_sheet[0]).to eq ["Vendor Name", "Factory Name", "Origin", "Co", "Entry Number", "Vendor Invoice Value", "Customs Value", "Difference", "Savings"]
      expect(summary_sheet[1]).to eq ["Vendco", "factory-1", "CN", "PO", "entry-1", 40.2, 9.0, 31.2, 10.39]
      expect(summary_sheet[2]).to eq ["Vendco-2", "factory-2", "IN", "PO", "entry-2", 72.22, 35, 37.22, 18.61]
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

      entry = Factory(:entry, importer_id:pvh.id, customer_number:"PVH", entry_number:"entry-1", transport_mode_code:"10", fiscal_date:Date.new(2018,12,22), release_date:Date.new(2018,12,25))
      inv = entry.commercial_invoices.create! invoice_number:"inv-1", master_bills_of_lading:"mbol-1"
      cont = Container.create! container_number: "cont-1"
      inv_line = inv.commercial_invoice_lines.create! vendor_name:"Vendco", po_number:"PO-A", quantity:nil, country_origin_code:"CN", contract_amount:nil, part_number:"part-A", container:cont, first_sale:true
      inv_line_tar = inv_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:nil, entered_value_7501:nil

      expect_any_instance_of(described_class).to receive(:get_po_line_values).and_return([nil,nil])

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVH_Cost_Savings_for_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 2
      expect(detail_sheet[0]).to eq ["Entry Number", "Customs Entry Date", "Vendor Name", "Factory Name", "PO Number", "PO Line Number", "Shipment", "Unit Cost (PO)", "Units Shipped", "Origin", "Invoice Number", "HTS Code", "Duty Rate PCT", "Vendor Invoice Value", "Customs Value", "Difference", "Savings", "% Difference"]
      expect(detail_sheet[1]).to eq ["entry-1", Date.new(2018,12,25), "Vendco", nil, "PO-A", nil, "cont-1", nil, nil, "CN", "inv-1", "235679012", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 2
      expect(summary_sheet[0]).to eq ["Vendor Name", "Factory Name", "Origin", "Co", "Entry Number", "Vendor Invoice Value", "Customs Value", "Difference", "Savings"]
      expect(summary_sheet[1]).to eq ["Vendco", nil, "CN", "PO", "entry-1", 0.0, 0.0, 0.0, 0.0]
    end

  end

  describe "run_schedulable" do
    it "calls run report method if configured day of fiscal month" do
      settings = {'email' => 'a@b.com'}
      current_fiscal_month = double("current fiscal month")
      expect(described_class).to receive(:run_if_configured).with(settings).and_yield(current_fiscal_month, double("fiscal date"))
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_first_cost_savings_report).with(settings, current_fiscal_month:current_fiscal_month).and_return "success"

      expect(described_class.run_schedulable(settings)).to eq("success")
    end

    it "does not call run report method if wrong day of fiscal month" do
      settings = {'email' => 'a@b.com'}
      # Does not yield.
      expect(described_class).to receive(:run_if_configured).with(settings)
      expect(subject).to_not receive(:run_first_cost_savings_report)

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
