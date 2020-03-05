describe OpenChain::Report::PvhCanadaDutyDiscountReport do

  describe "permission?" do
    it "uses permission logic from the US version of the report" do
      u = Factory(:user)
      expect(OpenChain::Report::PvhDutyDiscountReport).to receive(:permission?).with(u).and_return(true)
      expect(described_class.permission? u).to eq true
    end
  end

  describe "run_report" do
    let (:u) { Factory(:user) }
    let!(:pvh) { Factory(:company, name:'PVH Canada', system_code:'PVHCANADA') }

    after { @temp.close if @temp }

    it "generates spreadsheet" do
      fiscal_month = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:1, start_date:Date.new(2018,12,15), end_date:Date.new(2019,1,14))

      entry_1 = Factory(:entry, importer_id:pvh.id, customer_number:"PVHCANADA", entry_number:"entry-1", arrival_date:Date.new(2018,12,13), fiscal_date:Date.new(2018,12,15), transport_mode_code:'9', master_bills_of_lading:"A\nB", house_bills_of_lading:"C\nD", fcl_lcl:'LCL', release_date:Date.new(2019,8,23))
      inv_1 = entry_1.commercial_invoices.create! invoice_number:"inv-1", currency:"USD", exchange_rate:1.78
      inv_1_line_1 = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:10, value:BigDecimal.new("40.20"), part_number:"part-A", adjustments_amount:BigDecimal.new("-2.22"), miscellaneous_discount:(".35"), add_to_make_amount:(".55"), unit_price:BigDecimal.new("5.67")
      inv_1_line_1_tar = inv_1_line_1.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value:BigDecimal.new("3.21")
      inv_1_line_2 = inv_1.commercial_invoice_lines.create! po_number:"PO-A", quantity:11, value:BigDecimal.new("51.21"), part_number:"part-B", adjustments_amount:BigDecimal.new("1.21"), miscellaneous_discount:(".45"), add_to_make_amount:(".65"), unit_price:BigDecimal.new("6.78")
      inv_1_line_2_tar = inv_1_line_2.commercial_invoice_tariffs.create! hts_code:"356790123", duty_rate:BigDecimal.new(".667"), entered_value:BigDecimal.new("4.32")

      factory_1 = Factory(:factory, name:"factory-1")
      ord_1 = Factory(:order, importer_id:pvh.id, order_number:"PVHCANADA-PO-A", factory_id:factory_1.id)
      ord_1_line_1 = ord_1.order_lines.create! line_number:1, product_id:Factory(:product, importer_id:pvh.id).id
      ord_1_line_2 = ord_1.order_lines.create! line_number:3, product_id:Factory(:product, importer_id:pvh.id).id

      shipments = double("shipments")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("9", ["A","B"], ["C","D"], force_lookup:true).and_return(shipments)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("9", "LCL").twice.and_return(true)
      shipment_line_1 = double("shipment_line_1")
      cont_1 = Container.create! container_number: "cont-1"
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, nil, "PO-A", "part-A", 10, invoice_number:"inv-1").and_return(shipment_line_1)
      expect(shipment_line_1).to receive(:order_line).and_return(ord_1_line_1)
      expect(shipment_line_1).to receive(:container).and_return(cont_1)
      shipment_line_2 = double("shipment_line_2")
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments, nil, "PO-A", "part-B", 11, invoice_number:"inv-1").and_return(shipment_line_2)
      expect(shipment_line_2).to receive(:order_line).and_return(ord_1_line_2)
      expect(shipment_line_2).to receive(:container).and_return(cont_1)

      entry_2 = Factory(:entry, importer_id:pvh.id, customer_number:"PVHCANADA", entry_number:"entry-2", arrival_date:Date.new(2019,1,12), fiscal_date:Date.new(2019,1,14), transport_mode_code:'1', master_bills_of_lading:'C', house_bills_of_lading:'D', fcl_lcl:'FCL', release_date:Date.new(2019,8,24))
      inv_2 = entry_2.commercial_invoices.create! invoice_number:"inv-2", currency:"CAD", exchange_rate:1.5
      inv_2_line = inv_2.commercial_invoice_lines.create! po_number:"PO-C", quantity:12, value:BigDecimal.new("72.22"), part_number:"part-C", adjustments_amount:BigDecimal.new("-3.23"), miscellaneous_discount:(".55"), add_to_make_amount:(".75"), unit_price:BigDecimal.new("7.89")
      inv_2_line_tar = inv_2_line.commercial_invoice_tariffs.create! hts_code:"567901234", duty_rate:BigDecimal.new(".5"), entered_value:BigDecimal.new("5.43")

      factory_2 = Factory(:factory, name:"factory-2")
      ord_2 = Factory(:order, importer_id:pvh.id, order_number:"PVHCANADA-PO-C", factory_id:factory_2.id)
      ord_2_line = ord_2.order_lines.create! line_number:5, product_id:Factory(:product, importer_id:pvh.id).id

      shipments_2 = double("shipments_2")
      expect_any_instance_of(described_class).to receive(:find_shipments).with("1", ["C"], ["D"], force_lookup:true).and_return(shipments_2)
      expect_any_instance_of(described_class).to receive(:ocean_lcl_entry?).with("1", "FCL").and_return(false)
      shipment_line_3 = double("shipment_line_3")
      cont_2 = Container.create! container_number: "cont-2"
      expect_any_instance_of(described_class).to receive(:find_shipment_line).with(shipments_2, nil, "PO-C", "part-C", 12, invoice_number:nil).and_return(shipment_line_3)
      expect(shipment_line_3).to receive(:order_line).and_return(ord_2_line)
      expect(shipment_line_3).to receive(:container).and_return(cont_2)

      # Wrong customer number.
      entry_pvh_us = Factory(:entry, customer_number:"PVH", entry_number:"entry-3", fiscal_date:Date.new(2018,12,25), transport_mode_code:'9')
      # These should be excluded based on date.
      entry_too_old = Factory(:entry, customer_number:"PVHCANADA", entry_number:"entry-4", fiscal_date:Date.new(2018,12,14), transport_mode_code:'9')
      entry_too_new = Factory(:entry, customer_number:"PVHCANADA", entry_number:"entry-5", fiscal_date:Date.new(2019,1,15), transport_mode_code:'9')

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVHCANADA_Duty_Discount_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 6
      expect(detail_sheet[0]).to eq ["Entry Number", "Invoice Number", "PO Number", "Shipment Number", "PO Line", "Release Date", "ETA", "Currency Type", "Exchange Rate", "Vendor Invoice Value (USD)", "Tariff Entered Value (CAD)", "Duty Reductions (USD)", "Duty Additions (USD)", "Dutiable Value (USD)", "Duty Rate PCT", "Duty Adj Amount (USD)", "Duty Savings (USD)", "First Cost (USD)", "Units Shipped", "HTS Code", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 1, Date.new(2019,8,23), Date.new(2018,12,13), "USD", 1.78, 40.2, 3.21, -0.35, 0.55, 40.4, 33.3, -0.35, -0.12, 5.67, 10.0, "235679012", "SEA"]
      expect(detail_sheet[2]).to eq ["entry-1", "inv-1", "PO-A", "cont-1", 3, Date.new(2019,8,23), Date.new(2018,12,13), "USD", 1.78, 51.21, 4.32, -0.45, 0.65, 51.41, 66.7, -0.45, -0.3, 6.78, 11.0, "356790123", "SEA"]
      expect(detail_sheet[3]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, nil, nil, 91.41, nil, -0.8, 1.2, 91.81, nil, -0.8, -0.42, nil, nil, nil, nil]
      expect(detail_sheet[4]).to eq ["entry-2", "inv-2", "PO-C", "C", 5, Date.new(2019,8,24), Date.new(2019,1,12), "CAD", 1.5, 72.22, 5.43, -0.55, 0.75, 72.42, 50.0, -0.55, -0.28, 7.89, 12.0, "567901234", "AIR"]
      expect(detail_sheet[5]).to eq ["entry-2", nil, nil, nil, nil, nil, nil, nil, nil, 72.22, nil, -0.55, 0.75, 72.42, nil, -0.55, -0.28, nil, nil, nil, nil]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 3
      expect(summary_sheet[0]).to eq ["Entry Number", "ETA", "Vendor Invoice Value (USD)", "Duty Reductions (USD)", "Duty Additions (USD)", "Dutiable Value (USD)", "Duty Difference (USD)", "Duty Savings (USD)"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2018,12,13), 91.41, -0.8, 1.2, 91.81, -0.8, -0.42]
      expect(summary_sheet[2]).to eq ["entry-2", Date.new(2019,1,12), 72.22, -0.55, 0.75, 72.42, -0.55, -0.28]
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

      entry = Factory(:entry, importer_id:pvh.id, customer_number:"PVHCANADA", entry_number:"entry-1", arrival_date:Date.new(2019,8,13), fiscal_date:Date.new(2019,8,22), transport_mode_code:'1', master_bills_of_lading:'MBOL_X', release_date:Date.new(2019,8,23))
      inv = entry.commercial_invoices.create! invoice_number:"inv-1", currency:"CAD", exchange_rate:1.5
      inv_line = inv.commercial_invoice_lines.create! po_number:"PO-A", quantity:10, value:BigDecimal.new("20.20"), part_number:"part-A", adjustments_amount:BigDecimal.new("0.20"), miscellaneous_discount:(".35"), add_to_make_amount:(".55"), unit_price:BigDecimal.new("5.67")
      inv_line_tar = inv_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:BigDecimal.new(".333"), entered_value:33

      factory = Factory(:factory, name:"factory-1")
      ord = Factory(:order, importer_id:pvh.id, order_number:"PVHCANADA-PO-A", factory_id:factory.id)

      expect_any_instance_of(described_class).to receive(:get_po_line_values).and_return([14, nil])

      # These should be excluded based on date.
      entry_too_old = Factory(:entry, customer_number:"PVHCANADA", entry_number:"entry-4", fiscal_date:Date.new(2019,8,14), transport_mode_code:'1')
      entry_too_new = Factory(:entry, customer_number:"PVHCANADA", entry_number:"entry-5", fiscal_date:Date.new(2019,9,16), transport_mode_code:'1')

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {})
      end
      expect(@temp.original_filename).to eq "PVHCANADA_Duty_Discount_Fiscal_2019-09_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 3
      expect(detail_sheet[0]).to eq ["Entry Number", "Invoice Number", "PO Number", "Shipment Number", "PO Line", "Release Date", "ETA", "Currency Type", "Exchange Rate", "Vendor Invoice Value (USD)", "Tariff Entered Value (CAD)", "Duty Reductions (USD)", "Duty Additions (USD)", "Dutiable Value (USD)", "Duty Rate PCT", "Duty Adj Amount (USD)", "Duty Savings (USD)", "First Cost (USD)", "Units Shipped", "HTS Code", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", "MBOL_X", 14, Date.new(2019,8,23), Date.new(2019,8,13), "CAD", 1.5, 20.2, 33.0, -0.35, 0.55, 20.4, 33.3, -0.35, -0.12, 5.67, 10.0, "235679012", "AIR"]
      expect(detail_sheet[2]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, nil, nil, 20.2, nil, -0.35, 0.55, 20.4, nil, -0.35, -0.12, nil, nil, nil, nil]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 2
      expect(summary_sheet[0]).to eq ["Entry Number", "ETA", "Vendor Invoice Value (USD)", "Duty Reductions (USD)", "Duty Additions (USD)", "Dutiable Value (USD)", "Duty Difference (USD)", "Duty Savings (USD)"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2019,8,13), 20.2, -0.35, 0.55, 20.4, -0.35, -0.12]
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

    it "errors when PVH company is not found" do
      pvh.destroy!

      expect { described_class.run_report(u, {}) }.to raise_error("PVH company account could not be found.")
    end

    it "appropriately handles null number values" do
      fiscal_month = FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:1, start_date:Date.new(2018,12,15), end_date:Date.new(2019,1,14))

      entry = Factory(:entry, importer_id:pvh.id, customer_number:"PVHCANADA", entry_number:"entry-1", arrival_date:Date.new(2018,12,13), fiscal_date:Date.new(2018,12,22), transport_mode_code:"2")
      inv = entry.commercial_invoices.create! invoice_number:"inv-1"
      inv_line = inv.commercial_invoice_lines.create! po_number:"PO-A", quantity:nil, value:nil, part_number:"part-A", adjustments_amount:nil, non_dutiable_amount:BigDecimal.new("20.20"), miscellaneous_discount:nil, add_to_make_amount:nil
      inv_line_tar = inv_line.commercial_invoice_tariffs.create! hts_code:"235679012", duty_rate:nil, entered_value:nil

      expect_any_instance_of(described_class).to receive(:get_po_line_values).and_return([nil, nil])

      Timecop.freeze(make_eastern_date(2019,9,30)) do
        @temp = described_class.run_report(u, {'fiscal_month'=>'2019-01'})
      end
      expect(@temp.original_filename).to eq "PVHCANADA_Duty_Discount_Fiscal_2019-01_2019-09-30.xlsx"

      reader = XlsxTestReader.new(@temp.path).raw_workbook_data
      expect(reader.length).to eq 2

      detail_sheet = reader["Detail"]
      expect(detail_sheet).to_not be_nil
      expect(detail_sheet.length).to eq 3
      expect(detail_sheet[0]).to eq ["Entry Number", "Invoice Number", "PO Number", "Shipment Number", "PO Line", "Release Date", "ETA", "Currency Type", "Exchange Rate", "Vendor Invoice Value (USD)", "Tariff Entered Value (CAD)", "Duty Reductions (USD)", "Duty Additions (USD)", "Dutiable Value (USD)", "Duty Rate PCT", "Duty Adj Amount (USD)", "Duty Savings (USD)", "First Cost (USD)", "Units Shipped", "HTS Code", "Mode of Transport"]
      expect(detail_sheet[1]).to eq ["entry-1", "inv-1", "PO-A", nil, nil, nil, Date.new(2018,12,13), nil, nil, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, nil, "235679012", "TRUCK"]
      expect(detail_sheet[2]).to eq ["entry-1", nil, nil, nil, nil, nil, nil, nil, nil, 0.0, nil, 0.0, 0.0, 0.0, nil, 0.0, 0.0, nil, nil, nil, nil]

      summary_sheet = reader["Summary"]
      expect(summary_sheet).to_not be_nil
      expect(summary_sheet.length).to eq 2
      expect(summary_sheet[0]).to eq ["Entry Number", "ETA", "Vendor Invoice Value (USD)", "Duty Reductions (USD)", "Duty Additions (USD)", "Dutiable Value (USD)", "Duty Difference (USD)", "Duty Savings (USD)"]
      expect(summary_sheet[1]).to eq ["entry-1", Date.new(2018,12,13), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
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