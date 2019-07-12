describe OpenChain::Report::HmDrawbackExportReport do
  let!(:us_importer) { Factory(:company, system_code:"HENNE", name:"H&M USA") }

  describe "write_report_to_builder" do
    it "writes to builder" do
      ent_1 = Factory(:entry, entry_number:"ent-1", entry_filed_date:Date.new(2017,3,5), customer_number:"HMCAD", direct_shipment_date:Date.new(2017,5,3))
      inv_1 = Factory(:commercial_invoice, entry:ent_1, invoice_number:"123456-01")
      # This line has a matching I2 and product XREF, and 2 tariffs.
      inv_line_1 = Factory(:commercial_invoice_line, commercial_invoice:inv_1, po_number:"PO-A", part_number:"part-A", line_number:1, quantity:5)
      Factory(:commercial_invoice_tariff, commercial_invoice_line:inv_line_1, hts_code:"123456789")
      Factory(:commercial_invoice_tariff, commercial_invoice_line:inv_line_1, hts_code:"234567890")
      # This first I2 drawback line should be ignored because it's a "returns" type line.  The invoice line should
      # match to the second drawback line.
      HmI2DrawbackLine.create!(invoice_number:"123456", po_number:"PO-A", part_number:"part-A-55555", shipment_date:Date.new(2017,4,1), carrier:"car-A-wrong", customer_order_reference:"cust-ord-ref-1-wrong", carrier_tracking_number:"tracking-1-wrong", quantity:4, part_description:"part-desc-1-wrong", export_received:true, shipment_type:"returns")
      HmI2DrawbackLine.create!(invoice_number:"123456", po_number:"PO-A", part_number:"part-A-55555", shipment_date:Date.new(2017,4,2), carrier:"car-A", customer_order_reference:"cust-ord-ref-1", carrier_tracking_number:"tracking-1", quantity:3, part_description:"part-desc-1", export_received:true, shipment_type:"export")
      HmProductXref.create!(sku:"part-A-55555", color_description:"color-desc-A", size_description:"size-desc-A")

      # This line has no tariffs, I2 match or product XREF.
      inv_line_2 = Factory(:commercial_invoice_line, commercial_invoice:inv_1, po_number:"PO-A", part_number:"part-B", line_number:2, quantity:6)

      # This invoice shares an invoice number with invoice #1, but with a different suffix.
      inv_2 = Factory(:commercial_invoice, entry:ent_1, invoice_number:"123456-02")
      # This line has two matching I2s and product XREFs, one tariff.
      inv_line_3 = Factory(:commercial_invoice_line, commercial_invoice:inv_2, po_number:"PO-B", part_number:"part-B", line_number:1, quantity:7)
      Factory(:commercial_invoice_tariff, commercial_invoice_line:inv_line_3, hts_code:"456789012")
      HmI2DrawbackLine.create!(invoice_number:"123456", po_number:"PO-B", part_number:"part-B-55555", shipment_date:Date.new(2017,4,3), carrier:"car-B", customer_order_reference:"cust-ord-ref-2", carrier_tracking_number:"tracking-2", quantity:4, part_description:"part-desc-2", export_received:true, shipment_type:"export")
      HmI2DrawbackLine.create!(invoice_number:"123456", po_number:"PO-B", part_number:"part-B-55556", shipment_date:Date.new(2017,4,4), carrier:"car-C", customer_order_reference:"cust-ord-ref-3", carrier_tracking_number:"tracking-3", quantity:5, part_description:"part-desc-3", export_received:true, shipment_type:"export")
      HmProductXref.create!(sku:"part-B-55555", color_description:"color-desc-B", size_description:"size-desc-B")
      HmProductXref.create!(sku:"part-B-55556", color_description:"color-desc-C", size_description:"size-desc-C")

      ent_2 = Factory(:entry, entry_number:"ent-2", entry_filed_date:Date.new(2017,3,2), customer_number:"HMCAD", direct_shipment_date:Date.new(2017,5,2))
      inv_3 = Factory(:commercial_invoice, entry:ent_2, invoice_number:"123457-01")
      # This line has a matching I2 and product XREF, one tariff.
      inv_line_4 = Factory(:commercial_invoice_line, commercial_invoice:inv_3, po_number:"PO-C", part_number:"part-C", line_number:1, quantity:8)
      Factory(:commercial_invoice_tariff, commercial_invoice_line:inv_line_4, hts_code:"123456789")
      HmI2DrawbackLine.create!(invoice_number:"123457", po_number:"PO-C", part_number:"part-C-55555", shipment_date:Date.new(2017,4,2), carrier:"car-C", customer_order_reference:"cust-ord-ref-4", carrier_tracking_number:"tracking-4", quantity:2, part_description:"part-desc-4", export_received:false, shipment_type:"export")
      HmProductXref.create!(sku:"part-C-55555", color_description:"color-desc-D", size_description:"size-desc-D")

      # This line is ignored because it's before the date range.
      ent_3 = Factory(:entry, entry_number:"ent-3", entry_filed_date:Date.new(2017,2,28), customer_number:"HMCAD", direct_shipment_date:Date.new(2017,5,3))
      inv_4 = Factory(:commercial_invoice, entry:ent_3, invoice_number:"123458-01")
      Factory(:commercial_invoice_line, commercial_invoice:inv_4, po_number:"PO-D", part_number:"part-D", line_number:2, quantity:9)

      # This line is ignored because it's after the date range.
      ent_4 = Factory(:entry, entry_number:"ent-4", entry_filed_date:Date.new(2017,4,1), customer_number:"HMCAD", direct_shipment_date:Date.new(2017,5,3))
      inv_5 = Factory(:commercial_invoice, entry:ent_4, invoice_number:"123459-01")
      Factory(:commercial_invoice_line, commercial_invoice:inv_5, po_number:"PO-E", part_number:"part-E", line_number:3, quantity:10)

      # This is I2 content that does not match to anything in the invoice data above.  The first two lines are
      # within our date range, and should be included at the end of the dataset.  The second two I2 lines are
      # before and after the date range, respectively, and should be ignored.  Only the first I2 line has a matching
      # product xref.  The final I2 line here is of "returns" type and should be excluded.
      HmI2DrawbackLine.create!(invoice_number:"551234", po_number:"PO-F", part_number:"part-F-55555", shipment_date:Date.new(2017,3,2), carrier:"car-F", customer_order_reference:"cust-ord-ref-F", carrier_tracking_number:"tracking-5", quantity:42, part_description:"part-desc-5", export_received:true, shipment_type:"export")
      HmProductXref.create!(sku:"part-F-55555", color_description:"color-desc-F", size_description:"size-desc-F")
      HmI2DrawbackLine.create!(invoice_number:"551235", po_number:"PO-G", part_number:"part-G-55555", shipment_date:Date.new(2017,3,30), carrier:"car-G", customer_order_reference:"cust-ord-ref-G", carrier_tracking_number:"tracking-6", quantity:24, part_description:"part-desc-6", export_received:false, shipment_type:"export")
      HmI2DrawbackLine.create!(invoice_number:"551236", po_number:"PO-H", part_number:"part-H-55555", shipment_date:Date.new(2017,2,28), carrier:"car-H", customer_order_reference:"cust-ord-ref-H", carrier_tracking_number:"tracking-7", quantity:4, part_description:"part-desc-7", export_received:true, shipment_type:"export")
      HmI2DrawbackLine.create!(invoice_number:"551237", po_number:"PO-I", part_number:"part-I-55555", shipment_date:Date.new(2017,4,1), carrier:"car-I", customer_order_reference:"cust-ord-ref-I", carrier_tracking_number:"tracking-8", quantity:2, part_description:"part-desc-8", export_received:false, shipment_type:"export")
      HmI2DrawbackLine.create!(invoice_number:"551238", po_number:"PO-J", part_number:"part-J-55555", shipment_date:Date.new(2017,3,30), carrier:"car-J", customer_order_reference:"cust-ord-ref-J", carrier_tracking_number:"tracking-9", quantity:3, part_description:"part-desc-9", export_received:false, shipment_type:"returns")

      builder = subject.builder("csv")
      subject.write_report_to_builder builder, Date.new(2017,3,1), Date.new(2017,3,31)

      io = StringIO.new
      builder.write io
      io.rewind
      expect(io.read).to eq "EXPORT DATE,SHIP DATE,PART NUMBER,STYLE,COLOR DESCRIPTION,SIZE DESCRIPTION,CARRIER,LINE NUMBER,REF 1 - CANADIAN COMMERCIAL INVOICE NUMBER,REF 2 - CUSTOMER ORDER REFERENCE,REF 3 - CARRIER TRACKING NUMBER,REF 4 - CANADIAN ENTRY NUMBER,REF 5 - SALES ORDER NUMBER,REF 6 - EXPORT INVOICE NUMBER,DESTINATION COUNTRY,QUANTITY,QUANTITY (I2),SCHEDULE B CODE,DESCRIPTION,UOM,IMPORTER ID,MULTIPLE TARIFF?,EXPORT RECEIVED?\n" +
          "2017-05-03,2017-04-02,part-A-55555,part-A,color-desc-A,size-desc-A,car-A,1,123456-01,cust-ord-ref-1,tracking-1,ent-1,PO-A,123456,CA,5.0,3.0,123456789,part-desc-1,EA,H&M USA,Y,Y\n" +
          "2017-05-03,,,part-B,,,,2,123456-01,,,ent-1,PO-A,123456,CA,6.0,,,,EA,H&M USA,N,N\n" +
          "2017-05-03,2017-04-03,part-B-55555,part-B,color-desc-B,size-desc-B,car-B,1,123456-02,cust-ord-ref-2,tracking-2,ent-1,PO-B,123456,CA,7.0,4.0,456789012,part-desc-2,EA,H&M USA,N,Y\n" +
          "2017-05-03,2017-04-04,part-B-55556,part-B,color-desc-C,size-desc-C,car-C,1,123456-02,cust-ord-ref-3,tracking-3,ent-1,PO-B,123456,CA,7.0,5.0,456789012,part-desc-3,EA,H&M USA,N,Y\n" +
          "2017-05-02,2017-04-02,part-C-55555,part-C,color-desc-D,size-desc-D,car-C,1,123457-01,cust-ord-ref-4,tracking-4,ent-2,PO-C,123457,CA,8.0,2.0,123456789,part-desc-4,EA,H&M USA,N,N\n" +
          ",2017-03-02,part-F-55555,,color-desc-F,size-desc-F,car-F,,,cust-ord-ref-F,tracking-5,,PO-F,551234,CA,,42.0,,part-desc-5,EA,H&M USA,N,Y\n" +
          ",2017-03-30,part-G-55555,,,,car-G,,,cust-ord-ref-G,tracking-6,,PO-G,551235,CA,,24.0,,part-desc-6,EA,H&M USA,N,N\n"
    end

    it "raises error when US importer can't be found" do
      us_importer.destroy

      expect { subject.write_report_to_builder subject.builder("csv"), Date.new(2017,3,1), Date.new(2017,3,31) }.to raise_error "H&M importer with system code 'HENNE' not found."
    end
  end

  describe "run" do
    it "runs a report with provided dates" do
      expect(subject).to receive(:write_report_to_builder).with(instance_of(subject.builder("csv").class), Date.new(2016,1,1).beginning_of_day, Date.new(2016,12,31).end_of_day).and_call_original

      subject.run({"email_to"=>["a@b.com"], "start_date"=>"2016-01-01", "end_date"=>"2016-12-31"})

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com']
      expect(mail.subject).to eq "H&M Drawback Export Report"
      expect(mail.body).to include ERB::Util.html_escape("Your H&amp;M Drawback Export Report for 01/01/2016 - 12/31/2016 is attached.".html_safe)
      expect(mail.attachments.length).to eq(1)
      att = mail.attachments[0]
      expect(att.filename).to eq "hm_drawback_export_20160101_20161231.csv"
    end

    it "runs a report with defaulted dates" do
      current_date = Date.new(2018,10,15)

      expect(subject).to receive(:write_report_to_builder).with(instance_of(subject.builder("csv").class), Date.new(2018,1,1).beginning_of_day, Date.new(2018,3,31).end_of_day).and_call_original

      Timecop.freeze(current_date) do
        subject.run({"email_to"=>["a@b.com"]})
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.body).to include ERB::Util.html_escape("Your H&amp;M Drawback Export Report for 01/01/2018 - 03/31/2018 is attached.".html_safe)
      expect(mail.attachments.length).to eq(1)
      att = mail.attachments[0]
      expect(att.filename).to eq "hm_drawback_export_20180101_20180331.csv"
    end

    it "raises error when email addresses not provided" do
      expect { subject.run({}) }.to raise_error("An email_to setting containing an array of email addresses must be provided.")
    end

    it "raises error when email addresses are not an array" do
      expect { subject.run({"email_to"=>"a@b.com"}) }.to raise_error("An email_to setting containing an array of email addresses must be provided.")
    end
  end

end