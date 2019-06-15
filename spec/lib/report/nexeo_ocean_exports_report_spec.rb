describe OpenChain::Report::NexeoOceanExportsReport do

  

  context "with db data" do
    before :each do
      port = Factory(:port, schedule_d_code: "1234", name: "PORT")
      @nexeo = Factory(:importer, alliance_customer_number: "NEXEO")
      @shipment = Factory(:shipment, importer: @nexeo, importer_reference: "REF", vessel: "VESS", voyage: "VOY", est_departure_date: Date.new(2015, 12,1), lcl: false, 
                          house_bill_of_lading: "HBOL", booking_carrier: "CAR", master_bill_of_lading: "MBOL", freight_total: BigDecimal("123"), 
                          invoice_total: BigDecimal("150"), gross_weight: BigDecimal("10"), lading_port: port, buyer_address: Factory(:address, name: "BUYER"))
      @shipment.containers.create! container_number: "CONT"
      @shipment.comments.create! subject: "Discharge Port", body: "Discharge", user: User.integration
      @shipment.comments.create! subject: "Final Destination", body: "Dest", user: User.integration

      @order = Order.create! importer: @nexeo, order_number: "NEXEO-123", customer_order_number: "12345"
      product = Factory(:product, importer: @nexeo, unique_identifier: "NEXEO-PRODUCT")
      ol = @order.order_lines.create! product: product

      @shipment.shipment_lines.create! product: product, linked_order_line_id: ol.id
      DataCrossReference.create! cross_reference_type: DataCrossReference::EXPORT_CARRIER, key: "CAR", value: "CARRIER"

    end

    describe "run_report" do
      it "returns a nexeo report for FCL shipments" do
        f = described_class.run_report User.integration, start_date: "2015-12-01", end_date: "2015-12-02"

        wb = Spreadsheet.open(f.path)
        sheet = wb.worksheet 0

        expect(sheet.row(0)).to eq ["Consignee", "PO Number of Shipment Reference Number", "Shipping Number", "Vessel / Voyage", "Pick Up Location", "Port Of Loading", "ETD", "Port of Discharge", "Place of Delivery", "Container Number", "Size Type", "HBL", "Carrier", "MBL", "Freight", "Total", "Weight LBs"]
        r = sheet.row(1)
        expect(r[0]).to eq "BUYER"
        expect(r[1]).to eq "12345"
        expect(r[2]).to eq "REF"
        expect(r[3]).to eq "VESS V. VOY"
        expect(r[4]).to be_nil
        expect(r[5]).to eq "PORT"
        expect(r[6]).to eq Date.new(2015, 12, 1)
        expect(r[7]).to eq "Discharge"
        expect(r[8]).to eq "Dest"
        expect(r[9]).to eq "CONT"
        expect(r[10]).to eq nil
        expect(r[11]).to eq "HBOL"
        expect(r[12]).to eq "CARRIER"
        expect(r[13]).to eq "CARMBOL"
        expect(r[14]).to eq 123.0
        expect(r[15]).to eq 150.0
        expect(r[16]).to eq 22
      end

      it "returns a nexeo report for LCL shipments" do
        @shipment.update_attributes lcl: true

        f = described_class.run_report User.integration, start_date: "2015-12-01", end_date: "2015-12-02"

        wb = Spreadsheet.open(f.path)
        sheet = wb.worksheet 0

        r = sheet.row(1)
        expect(r[0]).to eq "BUYER"
        expect(r[1]).to eq "12345"
        expect(r[2]).to eq "REF"
        expect(r[3]).to eq "VESS V. VOY"
        expect(r[4]).to be_nil
        expect(r[5]).to eq "PORT"
        expect(r[6]).to eq Date.new(2015, 12, 1)
        expect(r[7]).to eq "Discharge"
        expect(r[8]).to eq "Dest"
        expect(r[9]).to eq "CONT"
        expect(r[10]).to eq "LCL"
        expect(r[11]).to eq "HBOL"
        expect(r[12]).to eq "CARRIER"
        expect(r[13]).to eq "COLOAD"
        expect(r[14]).to eq 123.0
        expect(r[15]).to eq 150.0
        expect(r[16]).to eq 22
      end

      it "does not return results for non-nexeo shipments" do
        @shipment.update_attributes importer: Factory(:importer)
        f = described_class.run_report User.integration, start_date: "2015-12-01", end_date: "2015-12-02"

        wb = Spreadsheet.open(f.path)
        sheet = wb.worksheet 0
        expect(sheet.row(1)).to be_blank
      end

      it "does not return results for dates after date range" do
        @shipment.update_attributes importer: Factory(:importer)
        f = described_class.run_report User.integration, start_date: "2015-12-01", end_date: "2015-12-01"

        wb = Spreadsheet.open(f.path)
        sheet = wb.worksheet 0
        expect(sheet.row(1)).to be_blank
      end

      it "does not return results for dates prior to the date range" do
        @shipment.update_attributes importer: Factory(:importer)
        f = described_class.run_report User.integration, start_date: "2015-12-02", end_date: "2015-12-03"

        wb = Spreadsheet.open(f.path)
        sheet = wb.worksheet 0
        expect(sheet.row(1)).to be_blank
      end
    end

    describe "run_schedulable" do
      it "runs a report over the last month" do
        now = Time.zone.parse "2016-01-01"
        allow(described_class).to receive(:now).and_return now

        described_class.run_schedulable({"email_to" => "me@there.com"})

        expect(ActionMailer::Base.deliveries.size).to eq 1
        email = ActionMailer::Base.deliveries.first
        expect(email.to).to eq ["me@there.com"]
        expect(email.subject).to eq "Nexeo Exports for Dec"
        expect(email.body.raw_source).to include "Attached is the Nexeo Export shipment report for December."
        expect(email.attachments["Exports 12-01-2015 - 01-01-2016.xls"]).not_to be_nil
        wb = Spreadsheet.open(StringIO.new(email.attachments["Exports 12-01-2015 - 01-01-2016.xls"].read))

        # Just make sure there's some data here.
        sheet = wb.worksheet 0

        r = sheet.row(1)
        expect(r[0]).to eq "BUYER"
      end
    end
  end

  describe "permission?" do
    before :each do
      ms = double("MasterSetup")
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:shipment_enabled).and_return true
      @nexeo = Factory(:importer, alliance_customer_number: "NEXEO")
    end

    it "allows users with view shipment permission and access to nexeo company to view" do
      user = Factory(:user, company: @nexeo, shipment_view: true)
      expect(described_class.permission? user).to be_truthy
    end

    it "disallows users not able to view nexeo company" do
      user = Factory(:user)
      expect(described_class.permission? user).to be_falsey
    end
  end
end