describe OpenChain::CustomHandler::Hm::HmI2DrawbackParser do

  def make_csv_file shipment_type
    "INVX;INV_line1;;20171218T0405+0100;CONSX;CONS_line1;POX;PO_line1;#{shipment_type};123456789;Description X;;CN;25;CARRX;CARRNOX;;;;ORDREFX;;;;;;;IN;RETREFX;78.90\n" +
    "INVY;INV_line2;;20161231T0505+0100;CONSY;CONS_line2;POY;PO_line2;#{shipment_type};987654321;Description Y;;IN;50;CARRY;CARRNOY;;;;ORDREFY;;;;;;;CN;RETREFY;10.50"
  end

  describe "parse_file" do
    let(:log) { InboundFile.new }
    let!(:importer) { create(:importer, system_code:'HENNE') }
    before(:each) {
      allow(subject).to receive(:inbound_file).and_return log
    }

    it "processes export sales file" do
      expect(Lock).to receive(:acquire).with('Invoice-INVX-hm_i2_drawback_export_invoice_number').and_yield
      expect(Lock).to receive(:with_lock_retry).and_yield

      subject.parse_file make_csv_file('ZSTO') + "\nPartial Line;not enough elements"

      expect(HmI2DrawbackLine.count).to eq 2

      i2_line_1 = HmI2DrawbackLine.where(invoice_number: 'INVX', invoice_line_number: 'INV_line1').first
      expect(i2_line_1).to_not be_nil
      expect(i2_line_1.shipment_date).to eq(Time.zone.parse('20171218T0405+0100'))
      expect(i2_line_1.consignment_number).to eq('CONSX')
      expect(i2_line_1.consignment_line_number).to eq('CONS_line1')
      expect(i2_line_1.po_number).to eq('POX')
      expect(i2_line_1.po_line_number).to eq('PO_line1')
      expect(i2_line_1.shipment_type).to eq('export')
      expect(i2_line_1.part_number).to eq('123456789')
      expect(i2_line_1.part_description).to eq('Description X')
      expect(i2_line_1.origin_country_code).to eq('CN')
      expect(i2_line_1.quantity).to eq(25)
      expect(i2_line_1.carrier).to eq('CARRX')
      expect(i2_line_1.carrier_tracking_number).to eq('CARRNOX')
      expect(i2_line_1.customer_order_reference).to eq('ORDREFX')
      expect(i2_line_1.country_code).to eq('IN')
      expect(i2_line_1.return_reference_number).to eq('RETREFX')
      expect(i2_line_1.item_value).to eq(BigDecimal("78.9"))
      expect(i2_line_1.export_received).to eq(true)

      i2_line_2 = HmI2DrawbackLine.where(invoice_number: 'INVY', invoice_line_number: 'INV_line2').first
      expect(i2_line_2).to_not be_nil
      expect(i2_line_2.shipment_date).to eq(Time.zone.parse('20161231T0505+0100'))
      expect(i2_line_2.consignment_number).to eq('CONSY')
      expect(i2_line_2.consignment_line_number).to eq('CONS_line2')
      expect(i2_line_2.po_number).to eq('POY')
      expect(i2_line_2.po_line_number).to eq('PO_line2')
      expect(i2_line_2.shipment_type).to eq('export')
      expect(i2_line_2.part_number).to eq('987654321')
      expect(i2_line_2.part_description).to eq('Description Y')
      expect(i2_line_2.origin_country_code).to eq('IN')
      expect(i2_line_2.quantity).to eq(50)
      expect(i2_line_2.carrier).to eq('CARRY')
      expect(i2_line_2.carrier_tracking_number).to eq('CARRNOY')
      expect(i2_line_2.customer_order_reference).to eq('ORDREFY')
      expect(i2_line_2.country_code).to eq('CN')
      expect(i2_line_2.return_reference_number).to eq('RETREFY')
      expect(i2_line_2.item_value).to eq(BigDecimal("10.5"))
      expect(i2_line_2.export_received).to eq(false)

      expect(log.company).to eq importer
    end

    it "reject dupe export sales file" do
      # Seeding this with a cross ref that contains a value for "value"  indicates that we're dealing with a dupe.
      DataCrossReference.where(cross_reference_type: DataCrossReference::HM_I2_DRAWBACK_EXPORT_INVOICE_NUMBER, key: 'INVX', value: Time.now).create!
      expect(Lock).to receive(:acquire).with('Invoice-INVX-hm_i2_drawback_export_invoice_number').and_yield
      expect(Lock).to receive(:with_lock_retry).and_yield

      subject.parse_file make_csv_file('ZSTO')

      expect(HmI2DrawbackLine.count).to eq(0)
    end

    it "processes returns file" do
      expect(Lock).to receive(:acquire).with('Invoice-INVX-hm_i2_drawback_returns_invoice_number').and_yield
      expect(Lock).to receive(:with_lock_retry).and_yield

      subject.parse_file make_csv_file('ZRET')

      expect(HmI2DrawbackLine.count).to eq 2

      i2_line_1 = HmI2DrawbackLine.where(invoice_number: 'INVX', invoice_line_number: 'INV_line1').first
      expect(i2_line_1).to_not be_nil
      expect(i2_line_1.shipment_type).to eq('returns')
    end

    it "processes mystery type file" do
      expect { subject.parse_file(make_csv_file('Mystery Type')) }.to raise_error(LoggedParserRejectionError, "Invalid Shipment Type value found: 'Mystery Type'.")
      expect(log).to have_reject_message("Invalid Shipment Type value found: 'Mystery Type'.")
    end

    it "processes file with matching line" do
      existing = HmI2DrawbackLine.where(invoice_number: 'INVX', invoice_line_number: 'INV_line1', shipment_type: 'export').first_or_create!

      subject.parse_file make_csv_file('ZSTO')

      i2_line_1 = HmI2DrawbackLine.where(invoice_number: 'INVX', invoice_line_number: 'INV_line1').first
      expect(i2_line_1).to_not be_nil
      expect(i2_line_1.id).to eq(existing.id)
      # Other fields updated as normal.  (Only need to verify one.)
      expect(i2_line_1.consignment_number).to eq('CONSX')
    end

    it "processes file with no shipment date" do
      # Blank value #4, shipment date, previously threw a nil-related exception.  This test ensures that that doesn't
      # happen anymore.
      csv_file = "INVX;INV_line1;;;CONSX;CONS_line1;POX;PO_line1;ZSTO;123456789;Description X;;CN;25;CARRX;CARRNOX;;;;ORDREFX;;;;;;;IN;RETREFX;78.90"

      subject.parse_file csv_file

      i2_line_1 = HmI2DrawbackLine.where(invoice_number: 'INVX', invoice_line_number: 'INV_line1').first
      expect(i2_line_1.export_received).to eq(false)
    end
  end

end