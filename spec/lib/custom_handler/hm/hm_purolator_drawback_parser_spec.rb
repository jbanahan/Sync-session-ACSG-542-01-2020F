describe OpenChain::CustomHandler::Hm::HmPurolatorDrawbackParser do

  describe "parse_file" do
    let(:log) { InboundFile.new }
    let!(:importer) { Factory(:importer, system_code:'HENNE') }
    before(:each) {
      allow(subject).to receive(:inbound_file).and_return log
    }

    it "processes file" do
      csv = "x,CARRNO1,0100,2018-01-01,x\n" +
            "x,CARRNO2,0104,2018-01-02,x\n" +
            "x,CARRNO3,0105,2018-01-03,x\n" +
            "x,CARRNO4,0106,2018-01-04,x\n" +
            "x,CARRNO5,0170,2018-01-05,x"

      line_1 = HmI2DrawbackLine.create!(carrier_tracking_number:'prefixCARRNO1suffix', shipment_type:'export', export_received:false, shipment_date:Date.new(2017, 3, 1))
      line_2 = HmI2DrawbackLine.create!(carrier_tracking_number:'CARRNO2', shipment_type:'export', export_received:false, shipment_date:Date.new(2017, 4, 2))
      line_3 = HmI2DrawbackLine.create!(carrier_tracking_number:'prefixCARRNO3', shipment_type:'export', export_received:false, shipment_date:Date.new(2017, 5, 3))
      line_4 = HmI2DrawbackLine.create!(carrier_tracking_number:'CARRNO4', shipment_type:'export', export_received:false, shipment_date:Date.new(2017, 6, 4))
      line_5 = HmI2DrawbackLine.create!(carrier_tracking_number:'CARRNO5', shipment_type:'export', export_received:false, shipment_date:Date.new(2018, 1, 4))
      line_6 = HmI2DrawbackLine.create!(carrier_tracking_number:'diffprefixCARRNO1suffix', shipment_type:'export', export_received:false, shipment_date:Date.new(2017, 8, 6))

      subject.parse_file csv

      line_1.reload
      expect(line_1.export_received).to eq(true)
      line_2.reload
      expect(line_2.export_received).to eq(true)
      line_3.reload
      expect(line_3.export_received).to eq(true)
      line_4.reload
      # This one has an event code connected to it ('0106') that is not considered valid for receipt.
      expect(line_4.export_received).to eq(false)
      line_5.reload
      expect(line_5.export_received).to eq(true)
      line_6.reload
      expect(line_6.export_received).to eq(true)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil

      expect(log.company).to eq importer
    end

    it "sends email about missing file lines" do
      csv = "x,CARRNO1,0100,2018-01-01,x\n" +
          "x,CARRNO2,0104,2018-01-02,x\n" +
          "x,CARRNO3,0100,2018-01-03,x"

      # Won't match because type is 'returns'.
      line_1 = HmI2DrawbackLine.create!(carrier_tracking_number:'CARRNO1', shipment_type:'returns', export_received:false)

      # Won't match because its shipment date occurs after the receipt date in the file.
      line_2 = HmI2DrawbackLine.create!(carrier_tracking_number:'CARRNO3', shipment_type:'export', export_received:false, shipment_date:Date.new(2018, 3, 1))

      subject.parse_file csv

      line_1.reload
      expect(line_1.export_received).to eq(false)
      line_2.reload
      expect(line_2.export_received).to eq(false)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to_not be_nil
      expect(mail.to).to eq ['support@vandegriftinc.com']
      expect(mail.subject).to eq 'H&M Drawback  - Purolator data file contains Tracking Numbers not in VFI Track'
      expect(mail.body).to include ERB::Util.html_escape("<p>The following Tracking Numbers do not exist in the VFI Track Drawback Database:<br><ul><li>CARRNO1</li><li>CARRNO2</li><li>CARRNO3</li></ul></p><p>Please forward this information to the Purolator Carrier for further review.</p>".html_safe)
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].filename).to eq('purolator_drawback.csv')
    end
  end

end