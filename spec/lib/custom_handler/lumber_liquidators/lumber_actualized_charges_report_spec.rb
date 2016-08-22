require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberActualizedChargesReport do

  describe "run_schedulable" do
    it "runs a report using the integration account over the previous Monday - Sunday" do
      start_date = ActiveSupport::TimeZone["America/New_York"].parse "2016-07-25 00:00"
      end_date = ActiveSupport::TimeZone["America/New_York"].parse "2016-08-01 00:00"

      expect_any_instance_of(described_class).to receive(:run).with(User.integration, start_date, end_date, {email_to: ["me@there.com"]})
      Timecop.freeze(Time.zone.parse "2016-08-03 12:00") do 
        described_class.run_schedulable({"email_to" => ["me@there.com"]})
      end
    end

    it "errors if settings doesn't include email_to attribute" do
      expect{described_class.run_schedulable({})}.to raise_error "Report must have an email_to attribute configured."
    end
  end

  describe "run_report" do
    it "executes the report" do
      user = User.new
      expect_any_instance_of(described_class).to receive(:run).with(user, "2016-08-02", "2016-08-03")
      described_class.run_report user, {"start_date" => "2016-08-02", "end_date" => "2016-08-03"}
    end
  end

  describe "permission?" do
    let (:user) { 
      u = User.new 
      u.company = Company.new 
      u
    }

    context "with custom feature enabled" do
      
      before :each do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("Lumber Charges Report").and_return true
      end

      context "with view permissions" do
        before :each do 
          allow(user).to receive(:view_broker_invoices?).and_return true
          allow(user).to receive(:view_entries?).and_return true
        end

        it "allows master user" do
          expect(user.company).to receive(:master?).and_return true
          expect(described_class.permission? user).to be_truthy
        end

        it "allows non-master user if can view Lumber company" do
          lumber = Factory(:importer, system_code: "LUMBER")
          expect_any_instance_of(Company).to receive(:can_view?).with(user).and_return true

          expect(described_class.permission? user).to be_truthy
        end
      end

      it "does not allow users without view_entries permission" do
        allow(user).to receive(:view_broker_invoices?).and_return true
        expect(described_class.permission? user).to be_falsey
      end

      it "does not allow users without view_broker_invoices permission" do
        allow(user).to receive(:view_entries?).and_return true
        expect(described_class.permission? user).to be_falsey
      end
    end

    it "does not allow access if custom feature is not enabled" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Lumber Charges Report").and_return false
      expect(described_class.permission? user).to be_falsey
    end
  end

  describe "run" do
    let! (:entry) {
      # Filling in just enough information so that we can tell an end to end test is working
      entry = Factory(:entry, customer_number: "LUMBER", source_system: "Alliance", release_date: "2016-08-02")
      container1 = entry.containers.create! container_number: "CONT1", container_size: "40"
      container2 = entry.containers.create! container_number: "CONT2", container_size: "20"

      invoice = entry.commercial_invoices.create! invoice_number: "123"
      line = invoice.commercial_invoice_lines.create! container: container1, po_number: "PO"
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("50")
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("50")

      line = invoice.commercial_invoice_lines.create! container: container2, po_number: "PO"
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("50")
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("50")

      inv = entry.broker_invoices.create! 
      inv.broker_invoice_lines.create! charge_code: "0007", charge_amount: BigDecimal("100"), charge_description: "Brokerage"

      entry 
    }

    let (:user) { Factory(:master_user, time_zone: "America/New_York") }

    after :each do 
      @tempfile.close! if @tempfile && !@tempfile.closed?
    end

    it 'runs a report' do
      # This test isn't getting deep into the guts of what's returned in each row, etc,
      # it's basically an integration test
      @tempfile = subject.run user, "2016-08-01", "2016-08-04"
      expect(@tempfile.original_filename).to eq "Actualized Charges 2016-08-01 - 2016-08-04.xls"

      wb = Spreadsheet.open(@tempfile.path)
      sheet = wb.worksheets.first

      expect(sheet.rows.length).to eq 3
      expect(sheet.row(0)[0]).to eq "Ship Date"
      expect(sheet.row(1)[11]).to eq "CONT1"
      expect(sheet.row(1)[24]).to eq BigDecimal("50")
      expect(sheet.row(2)[11]).to eq "CONT2"
      expect(sheet.row(2)[24]).to eq BigDecimal("50")
    end

    it "emails a report" do
      subject.run user, "2016-08-01", "2016-08-04", email_to: ["me@there.com"]

      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "[VFI Track] Actualized Charges Report"
      expect(m.attachments["Actualized Charges 2016-08-01 - 2016-08-04.xls"]).not_to be_nil
    end
  end

  describe "generate_entry_data" do
    let (:entry_port) { Port.create! schedule_d_code: "1234", name: "Entry Port" }
    let (:lading_port) { Port.create! schedule_k_code: "12345", name: "Lading Port" }
    let (:entry) {
      # Filling in just enough information so that we can tell an end to end test is working
      entry = Factory(:entry, customer_number: "LUMBER", source_system: "Alliance", release_date: "2016-08-02", export_date: "2016-07-01", entry_port_code: entry_port.schedule_d_code, lading_port_code: lading_port.schedule_k_code, broker_reference: "REF", entry_number: "ENT", carrier_code: "CARR", master_bills_of_lading: "MBOL", vessel: "VESS", eta_date: "2016-08-05", entered_value: BigDecimal("100"))
      container1 = entry.containers.create! container_number: "CONT1", container_size: "40"
      container2 = entry.containers.create! container_number: "CONT2", container_size: "20"

      invoice = entry.commercial_invoices.create! invoice_number: "123"
      line = invoice.commercial_invoice_lines.create! container: container1, po_number: "PO", add_duty_amount: BigDecimal("10"), cvd_duty_amount: BigDecimal("20"), vendor_name: "Vendor 1", quantity: BigDecimal("200"), hmf: BigDecimal("1"), prorated_mpf: BigDecimal("2")
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("25"), duty_amount: BigDecimal("25")
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("50"), duty_amount: BigDecimal("25")

      line = invoice.commercial_invoice_lines.create! container: container2, po_number: "PO", add_duty_amount: BigDecimal("30"), cvd_duty_amount: BigDecimal("40"), vendor_name: "Vendor 2", quantity: BigDecimal("100"), hmf: BigDecimal("3"), prorated_mpf: BigDecimal("4")
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("12.50"), duty_amount: BigDecimal("10")
      tariff = line.commercial_invoice_tariffs.create! gross_weight: BigDecimal("100"), entered_value: BigDecimal("12.50"), duty_amount: BigDecimal("10")

      inv = entry.broker_invoices.create! 
      inv.broker_invoice_lines.create! charge_code: "0007", charge_amount: BigDecimal("100"), charge_description: "Brokerage"
      inv.broker_invoice_lines.create! charge_code: "0004", charge_amount: BigDecimal("200"), charge_description: "Ocean Rate"
      inv.broker_invoice_lines.create! charge_code: "0191", charge_amount: BigDecimal("300"), charge_description: "ISF"
      inv.broker_invoice_lines.create! charge_code: "0142", charge_amount: BigDecimal("400"), charge_description: "Acessorial"
      inv.broker_invoice_lines.create! charge_code: "0189", charge_amount: BigDecimal("500"), charge_description: "Pier Pass"
      inv.broker_invoice_lines.create! charge_code: "0193", charge_amount: BigDecimal("600"), charge_description: "Clean Truck"
      inv.broker_invoice_lines.create! charge_code: "0235", charge_amount: BigDecimal("700"), charge_description: "CPM Fee"
      inv.broker_invoice_lines.create! charge_code: "0016", charge_amount: BigDecimal("800"), charge_description: "Courier"

      entry 
    }

    it "turns entry data into row values for the spreadsheet" do
      data = subject.generate_entry_data entry
      expect(data.length).to eq 2

      l = data.first
      expect(l[:ship_date]).to eq Date.new(2016, 7, 1)
      expect(l[:port_of_entry]).to eq "Entry Port"
      expect(l[:broker_reference]).to eq "REF"
      expect(l[:entry_number]).to eq "ENT"
      expect(l[:carrier_code]).to eq "CARR"
      expect(l[:master_bill]).to eq "MBOL"
      expect(l[:vessel]).to eq "VESS"
      expect(l[:eta_date]).to eq Date.new(2016, 8, 5)
      expect(l[:origin]).to eq "Lading Port"
      expect(l[:container_number]).to eq "CONT1"
      expect(l[:container_size]).to eq "40"
      expect(l[:po_numbers]).to eq "PO"
      expect(l[:vendors]).to eq "Vendor 1"
      expect(l[:quantity]).to eq BigDecimal("200")
      expect(l[:gross_weight_kg]).to eq 200
      expect(l[:gross_weight]).to eq BigDecimal("440.92")
      expect(l[:ocean_rate]).to eq BigDecimal("150")
      expect(l[:brokerage]).to eq BigDecimal("75")
      expect(l[:acessorial]).to eq BigDecimal("300")
      expect(l[:isf]).to eq BigDecimal("225")
      expect(l[:pier_pass]).to eq BigDecimal("375")
      expect(l[:clean_truck]).to eq BigDecimal("450")
      expect(l[:duty]).to eq BigDecimal("50")
      expect(l[:cvd]).to eq BigDecimal("20")
      expect(l[:add]).to eq BigDecimal("10")
      expect(l[:isc_management]).to eq BigDecimal("525")
      expect(l[:mpf]).to eq 2
      expect(l[:hmf]).to eq 1
      expect(l[:courier]).to eq 600

      l = data.second
      expect(l[:ship_date]).to eq Date.new(2016, 7, 1)
      expect(l[:port_of_entry]).to eq "Entry Port"
      expect(l[:broker_reference]).to eq "REF"
      expect(l[:entry_number]).to eq "ENT"
      expect(l[:carrier_code]).to eq "CARR"
      expect(l[:master_bill]).to eq "MBOL"
      expect(l[:vessel]).to eq "VESS"
      expect(l[:eta_date]).to eq Date.new(2016, 8, 5)
      expect(l[:origin]).to eq "Lading Port"
      expect(l[:container_number]).to eq "CONT2"
      expect(l[:container_size]).to eq "20"
      expect(l[:po_numbers]).to eq "PO"
      expect(l[:vendors]).to eq "Vendor 2"
      expect(l[:quantity]).to eq BigDecimal("100")
      expect(l[:gross_weight_kg]).to eq 200
      expect(l[:gross_weight]).to eq BigDecimal("440.92")
      expect(l[:ocean_rate]).to eq BigDecimal("50")
      expect(l[:brokerage]).to eq BigDecimal("25")
      expect(l[:acessorial]).to eq BigDecimal("100")
      expect(l[:isf]).to eq BigDecimal("75")
      expect(l[:pier_pass]).to eq BigDecimal("125")
      expect(l[:clean_truck]).to eq BigDecimal("150")
      expect(l[:duty]).to eq BigDecimal("20")
      expect(l[:cvd]).to eq BigDecimal("40")
      expect(l[:add]).to eq BigDecimal("30")
      expect(l[:isc_management]).to eq BigDecimal("175")
      expect(l[:mpf]).to eq 4
      expect(l[:hmf]).to eq 3
      expect(l[:courier]).to eq 200
    end

    it "handles value prorations with uneven splits" do
      entry.update_attributes entered_value: "30"
      invoice = entry.commercial_invoices.first
      tariffs = invoice.commercial_invoice_lines.first.commercial_invoice_tariffs
      tariffs.first.update_attributes! entered_value: BigDecimal("10")
      tariffs.second.update_attributes! entered_value: BigDecimal("10")

      tariffs = invoice.commercial_invoice_lines.second.commercial_invoice_tariffs
      tariffs.first.update_attributes! entered_value: BigDecimal("5")
      tariffs.second.update_attributes! entered_value: BigDecimal("5")


      data = subject.generate_entry_data entry
      expect(data.length).to eq 2

      l = data.first
      expect(l[:ocean_rate]).to eq BigDecimal("133.333")
      expect(l[:brokerage]).to eq BigDecimal("66.667")
      expect(l[:isf]).to eq BigDecimal("200")
      expect(l[:acessorial]).to eq BigDecimal("266.667")
      expect(l[:pier_pass]).to eq BigDecimal("333.333")
      expect(l[:clean_truck]).to eq BigDecimal("400")

      l = data.second
      expect(l[:ocean_rate]).to eq BigDecimal("66.667")
      expect(l[:brokerage]).to eq BigDecimal("33.333")
      expect(l[:isf]).to eq BigDecimal("100")
      expect(l[:acessorial]).to eq BigDecimal("133.333")
      expect(l[:pier_pass]).to eq BigDecimal("166.667")
      expect(l[:clean_truck]).to eq BigDecimal("200")
    end
  end

  describe "write_entry_values" do
    let (:entry_values) {
      [
        [
          {
            ship_date: Date.new(2016, 8, 1),
            port_of_entry: "Entry",
            broker_reference: "REF",
            entry_number: "ENT",
            po_numbers: "PO",
            vendors: "VEND",
            container_number: "CONT1",
            container_size: "20",
            carrier_code: "CAR",
            master_bill: "MBOL",
            vessel: "VESS",
            eta_date: Date.new(2016, 8, 2),
            quantity: BigDecimal("20"),
            gross_weight: BigDecimal("30"),
            ocean_rate: BigDecimal("40"),
            brokerage: BigDecimal("50"),
            acessorial: BigDecimal("60"),
            isf: BigDecimal("70"),
            pier_pass: BigDecimal("80"),
            clean_truck: BigDecimal("90"),
            duty: BigDecimal("100"),
            origin: "LADING",
            cvd: BigDecimal("110"),
            add: BigDecimal("120"),
            isc_management: BigDecimal("130"),
            courier: BigDecimal("140"),
            hmf: BigDecimal("5"),
            mpf: BigDecimal("4")
          }
        ]
      ]
    }

    it "writes given values to new spreadsheet" do
      wb = subject.write_entry_values "Sheet Name", entry_values
      sheet = wb.worksheets.first
      expect(sheet.name).to eq "Sheet Name"

      expect(sheet.rows.length).to eq 2
      expect(sheet.row(0)).to eq ["Ship Date", "", "Port of Entry", "", "", "", "Broker Reference", "Entry Number", "", "PO Number", "Vendor", "Container Number", "", "Container Size", "Carrier Code", "Master Bill", "", "Vessel", "ETA Date", "Quantity", "Gross Weight (KG)", "Gross Weight (LB)", "Ocean Freight", "", "Custom Clearance Fees", "Additional Charges", "CPM Fee", "ISF Fee", "CCC Charges", "Pier Pass / Clean Truck Fee", "", "MSC Charges", "Customs Duty", "", "", "Bill of Lading Origin", "Origin Port", "", "", "", "Countervailing Duty", "Anti Dumpting Duty", "Contract #"]
      row = sheet.row(1)

      expect(row[0]).to eq Date.new(2016,8,1)
      expect(row[2]).to eq "Entry"
      expect(row[6]).to eq "REF"
      expect(row[7]).to eq "ENT"
      expect(row[9]).to eq "PO"
      expect(row[10]).to eq "VEND"
      expect(row[11]).to eq "CONT1"
      expect(row[13]).to eq "20"
      expect(row[14]).to eq "CAR"
      expect(row[15]).to eq "MBOL"
      expect(row[17]).to eq "VESS"
      expect(row[18]).to eq Date.new(2016, 8, 2)
      expect(row[19]).to eq BigDecimal("20")
      expect(row[21]).to eq BigDecimal("30")
      expect(row[22]).to eq BigDecimal("40")
      expect(row[24]).to eq BigDecimal("50")
      expect(row[25]).to eq BigDecimal("140")
      expect(row[26]).to eq BigDecimal("130")
      expect(row[27]).to eq BigDecimal("70")
      expect(row[29]).to eq BigDecimal("170")
      expect(row[31]).to eq BigDecimal("60")
      expect(row[32]).to eq BigDecimal("109")
      expect(row[36]).to eq "LADING"
      expect(row[40]).to eq BigDecimal("110")
      expect(row[41]).to eq BigDecimal("120")
    end
  end
end