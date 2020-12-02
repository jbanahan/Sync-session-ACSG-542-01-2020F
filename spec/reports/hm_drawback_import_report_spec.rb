describe OpenChain::Report::HmDrawbackImportReport do

  describe "write_report_to_builder" do
    it "writes to builder" do
      ent_1 = create(:entry, entry_number:"ent-1", entry_filed_date:Date.new(2017, 3, 5), customer_number:"HENNE",
                      import_date:Date.new(2017, 5, 3), entry_port_code:"YYZ", total_duty:5, total_fees:6,
                      liquidation_date:DateTime.new(2017, 4, 2, 5, 30), entered_value:7, mpf:8, merchandise_description:"Merch_X",
                      transport_mode_code:"10", total_taxes:9, summary_line_count:5)
      inv_1 = create(:commercial_invoice, entry:ent_1, invoice_number:"123456", exchange_rate:1)
      # This line has a matching receipt file line and product XREF, and 2 tariffs.
      inv_line_1 = create(:commercial_invoice_line, commercial_invoice:inv_1, po_number:"PO-A", part_number:"part-A",
                           customs_line_number:1, quantity:5, country_origin_code:"CN", country_export_code:"US",
                           unit_of_measure:"CM", unit_price:5.99)
      create(:commercial_invoice_tariff, commercial_invoice_line:inv_line_1, hts_code:"123456789", tariff_description:"tar-1",
              classification_qty_1: 55, classification_qty_2:88, duty_rate:0.55, duty_amount:5.35, entered_value:4.62,
              entered_value_7501:5.34, spi_primary:"G")
      create(:commercial_invoice_tariff, commercial_invoice_line:inv_line_1, hts_code:"234567890", tariff_description:"tar-2",
              classification_qty_1: 66, classification_qty_2:77, duty_rate:0.45, duty_amount:5.36, entered_value:5.63,
              entered_value_7501:6.35, spi_primary:"H")
      HmReceiptLine.create!(order_number:"123456", sku:"part-A-55555", delivery_date:Date.new(2017, 4, 2), quantity:3)
      HmProductXref.create!(sku:"part-A-55555", color_description:"color-desc-A", size_description:"size-desc-A")

      # This line has no tariffs, receipt file line match or product XREF.
      inv_line_2 = create(:commercial_invoice_line, commercial_invoice:inv_1, po_number:"PO-A", part_number:"part-B",
                           customs_line_number:2, quantity:6, country_origin_code:"CO", country_export_code:"UT",
                           unit_of_measure:"GA", unit_price:6.88)

      inv_2 = create(:commercial_invoice, entry:ent_1, invoice_number:"123460", exchange_rate:0.5)
      # This line has two matching receipt file lines and product XREFs, one tariff.
      inv_line_3 = create(:commercial_invoice_line, commercial_invoice:inv_2, po_number:"PO-B", part_number:"part-B",
                           customs_line_number:1, quantity:7, country_origin_code:"CP", country_export_code:"UU",
                           unit_of_measure:"KM", unit_price:7.77)
      create(:commercial_invoice_tariff, commercial_invoice_line:inv_line_3, hts_code:"456789012", tariff_description:"tar-3",
              classification_qty_1: 77, classification_qty_2:66, duty_rate:0.35, duty_amount:5.37, entered_value:6.64,
              entered_value_7501:7.36, spi_primary:"I")
      HmReceiptLine.create!(order_number:"123460", sku:"part-B-55555", delivery_date:Date.new(2017, 4, 3), quantity:4)
      HmReceiptLine.create!(order_number:"123460", sku:"part-B-55556", delivery_date:Date.new(2017, 4, 4), quantity:5)
      HmProductXref.create!(sku:"part-B-55555", color_description:"color-desc-B", size_description:"size-desc-B")
      HmProductXref.create!(sku:"part-B-55556", color_description:"color-desc-C", size_description:"size-desc-C")

      ent_2 = create(:entry, entry_number:"ent-2", entry_filed_date:Date.new(2017, 3, 2), customer_number:"HENNE",
                      import_date:Date.new(2017, 5, 2), entry_port_code:"ZYZ", total_duty:6, total_fees:7,
                      liquidation_date:DateTime.new(2017, 4, 3, 6, 25), entered_value:8, mpf:9, merchandise_description:"Merch_Y",
                      transport_mode_code:"11", total_taxes:9, summary_line_count:6)
      inv_3 = create(:commercial_invoice, entry:ent_2, invoice_number:"123457", exchange_rate:0.75)
      # This line has a matching receipt file line and product XREF, one tariff.
      inv_line_4 = create(:commercial_invoice_line, commercial_invoice:inv_3, po_number:"PO-C", part_number:"part-C",
                           customs_line_number:1, quantity:8, country_origin_code:"CQ", country_export_code:"UV",
                           unit_of_measure:"ML", unit_price:8.66)
      create(:commercial_invoice_tariff, commercial_invoice_line:inv_line_4, hts_code:"123456789", tariff_description:"tar-4",
              classification_qty_1: 88, classification_qty_2:55, duty_rate:0.25, duty_amount:5.37, entered_value:7.65,
              entered_value_7501:8.37, spi_primary:"J")
      HmReceiptLine.create!(order_number:"123457", sku:"part-C-55555", delivery_date:Date.new(2017, 4, 2), quantity:2)
      HmProductXref.create!(sku:"part-C-55555", color_description:"color-desc-D", size_description:"size-desc-D")

      # This line is ignored because it's before the date range.
      ent_3 = create(:entry, entry_number:"ent-3", entry_filed_date:Date.new(2017, 2, 28), customer_number:"HENNE")
      inv_4 = create(:commercial_invoice, entry:ent_3, invoice_number:"123458")
      create(:commercial_invoice_line, commercial_invoice:inv_4, po_number:"PO-D", part_number:"part-D", quantity:9)

      # This line is ignored because it's after the date range.
      ent_4 = create(:entry, entry_number:"ent-4", entry_filed_date:Date.new(2017, 4, 1), customer_number:"HENNE")
      inv_5 = create(:commercial_invoice, entry:ent_4, invoice_number:"123459")
      create(:commercial_invoice_line, commercial_invoice:inv_5, po_number:"PO-E", part_number:"part-E", quantity:10)

      # This is receipt line content that does not match to anything in the invoice data above.  The first two lines are
      # within our date range, and should be included at the end of the dataset.  The second two receipt lines are
      # before and after the date range, respectively, and should be ignored.  Only the first receipt line has a matching
      # product xref.
      HmReceiptLine.create!(order_number:"551234", sku:"part-D-55555", delivery_date:Date.new(2017, 3, 2), quantity:42)
      HmProductXref.create!(sku:"part-D-55555", color_description:"color-desc-E", size_description:"size-desc-E")
      HmReceiptLine.create!(order_number:"551235", sku:"part-E-55555", delivery_date:Date.new(2017, 3, 30), quantity:24)
      HmReceiptLine.create!(order_number:"551236", sku:"part-F-55555", delivery_date:Date.new(2017, 2, 28), quantity:4)
      HmReceiptLine.create!(order_number:"551237", sku:"part-F-55555", delivery_date:Date.new(2017, 4, 1), quantity:2)

      builder = subject.builder("csv")
      subject.write_report_to_builder builder, Date.new(2017, 3, 1), Date.new(2017, 3, 31)

      io = StringIO.new
      builder.write io
      io.rewind

      expect(io.read).to eq "IMPORT #,IMPORT DATE,RECEIVED DATE,MFG DATE,PORT,TOTAL DUTY,\"TOTAL DUTY, TAXES, FEES & PENALTIES\",LIQUIDATION DATE,TOTAL ENTERED VALUE,MPF,CONVERSION,CUSTOMER NUMBER,REF 1 - INVOICE NUMBER,REF 2 - ORDER NUMBER,REF 3 - DEPT NO,INVOICE LINE - COUNTRY ORIGIN CODE,INVOICE LINE - COUNTRY EXPORT CODE,CD,SKU,STYLE,COLOR,SIZE,EXTERNAL PART,HTS,DESCRIPTION,UNITS,YIELD,RECEIPT QTY,QTY,AVAILABLE QTY,QTY 2,DUTY VALUE 1,DUTY VALUE 2,DUTY VALUE 3,DUTY VALUE 4,RATE 1,RATE 2,RATE 3,RATE 4,DUTY EACH,COMPUTE CODE,STATUS,OCEAN INDICATOR,INVOICE LINE - CUSTOMS LINE NUMBER,HTS DUTY,HTS ENTERED VALUE,HTS QTY,HTS VALUE,UNITS 2,HTS2,HTS3,HTS4,TOTAL TAXES,INVOICE TARIFF - SPI - PRIMARY,ENTRY SUMMARY LINE COUNT,MULTIPLE TARIFF?\n" +
            "ent-1,2017-05-03,2017-04-02,,YYZ,5.0,11.0,2017-04-02,7.0,8.0,1.0,HENNE,123456,PO-A,,CN,US,,part-A-55555,part-A,color-desc-A,size-desc-A,,123456789,Merch_X - tar-1,CM,1,3,5.0,5.0,88.0,5.99,,,,0.55,,,,1.07,7,,Y,1,5.35,4.62,55.0,5,,,,,9.0,G,5,Y\n" +
            "ent-1,2017-05-03,,,YYZ,5.0,11.0,2017-04-02,7.0,8.0,1.0,HENNE,123456,PO-A,,CO,UT,,,part-B,,,,,Merch_X - ,GA,1,,6.0,6.0,,6.88,,,,,,,,,7,,Y,2,,,,,,,,,9.0,,5,N\n" +
            "ent-1,2017-05-03,2017-04-03,,YYZ,5.0,11.0,2017-04-02,7.0,8.0,0.5,HENNE,123460,PO-B,,CP,UU,,part-B-55555,part-B,color-desc-B,size-desc-B,,456789012,Merch_X - tar-3,KM,1,4,7.0,7.0,66.0,7.77,,,,0.35,,,,0.767142857142857142857142857,7,,Y,1,5.37,6.64,77.0,7,,,,,9.0,I,5,N\n" +
            "ent-1,2017-05-03,2017-04-04,,YYZ,5.0,11.0,2017-04-02,7.0,8.0,0.5,HENNE,123460,PO-B,,CP,UU,,part-B-55556,part-B,color-desc-C,size-desc-C,,456789012,Merch_X - tar-3,KM,1,5,7.0,7.0,66.0,7.77,,,,0.35,,,,0.767142857142857142857142857,7,,Y,1,5.37,6.64,77.0,7,,,,,9.0,I,5,N\n" +
            "ent-2,2017-05-02,2017-04-02,,ZYZ,6.0,13.0,2017-04-03,8.0,9.0,0.75,HENNE,123457,PO-C,,CQ,UV,,part-C-55555,part-C,color-desc-D,size-desc-D,,123456789,Merch_Y - tar-4,ML,1,2,8.0,8.0,55.0,8.66,,,,0.25,,,,0.67125,7,,Y,1,5.37,7.65,88.0,8,,,,,9.0,J,6,N\n" +
            ",,2017-03-02,,,,0.0,,,,,HENNE,551234,,,,,,part-D-55555,,color-desc-E,size-desc-E,,, - ,,1,42,,,,,,,,,,,,,7,,,,,,,,,,,,,,,N\n" +
            ",,2017-03-30,,,,0.0,,,,,HENNE,551235,,,,,,part-E-55555,,,,,, - ,,1,24,,,,,,,,,,,,,7,,,,,,,,,,,,,,,N\n"
    end

    it "handles nils and missing values" do
      ent_1 = create(:entry, entry_number:"ent-1", entry_filed_date:Date.new(2017, 3, 5), customer_number:"HENNE")
      inv_1 = create(:commercial_invoice, entry:ent_1, invoice_number:"123456")
      inv_line_1 = create(:commercial_invoice_line, commercial_invoice:inv_1, po_number:"PO-A", part_number:"part-A")
      create(:commercial_invoice_tariff, commercial_invoice_line:inv_line_1)
      HmReceiptLine.create!(order_number:"123456", sku:"part-A-55555")
      HmProductXref.create!(sku:"part-A-55555")

      builder = subject.builder("csv")
      subject.write_report_to_builder builder, Date.new(2017, 3, 1), Date.new(2017, 3, 31)

      io = StringIO.new
      builder.write io
      io.rewind

      expect(io.read).to eq "IMPORT #,IMPORT DATE,RECEIVED DATE,MFG DATE,PORT,TOTAL DUTY,\"TOTAL DUTY, TAXES, FEES & PENALTIES\",LIQUIDATION DATE,TOTAL ENTERED VALUE,MPF,CONVERSION,CUSTOMER NUMBER,REF 1 - INVOICE NUMBER,REF 2 - ORDER NUMBER,REF 3 - DEPT NO,INVOICE LINE - COUNTRY ORIGIN CODE,INVOICE LINE - COUNTRY EXPORT CODE,CD,SKU,STYLE,COLOR,SIZE,EXTERNAL PART,HTS,DESCRIPTION,UNITS,YIELD,RECEIPT QTY,QTY,AVAILABLE QTY,QTY 2,DUTY VALUE 1,DUTY VALUE 2,DUTY VALUE 3,DUTY VALUE 4,RATE 1,RATE 2,RATE 3,RATE 4,DUTY EACH,COMPUTE CODE,STATUS,OCEAN INDICATOR,INVOICE LINE - CUSTOMS LINE NUMBER,HTS DUTY,HTS ENTERED VALUE,HTS QTY,HTS VALUE,UNITS 2,HTS2,HTS3,HTS4,TOTAL TAXES,INVOICE TARIFF - SPI - PRIMARY,ENTRY SUMMARY LINE COUNT,MULTIPLE TARIFF?\n" +
            "ent-1,,,,,,0.0,,,,,HENNE,123456,PO-A,,,,,part-A-55555,part-A,,,,, - ,,1,,,,,,,,,,,,,,7,,,,,,,,,,,,,,,N\n"
    end

    # Ensures we are preventing a divide by zero exception caused when HTS duty amount had a value and invoice line
    # quantity had a zero value.
    it "handles zero invoice line quantity" do
      ent_1 = create(:entry, entry_number:"ent-1", entry_filed_date:Date.new(2017, 3, 5), customer_number:"HENNE")
      inv_1 = create(:commercial_invoice, entry:ent_1, invoice_number:"123456")
      inv_line_1 = create(:commercial_invoice_line, commercial_invoice:inv_1, po_number:"PO-A", part_number:"part-A", quantity:0)
      create(:commercial_invoice_tariff, commercial_invoice_line:inv_line_1, duty_amount:5.55)

      builder = subject.builder("csv")
      subject.write_report_to_builder builder, Date.new(2017, 3, 1), Date.new(2017, 3, 31)

      io = StringIO.new
      builder.write io
      io.rewind

      expect(io.read).to eq "IMPORT #,IMPORT DATE,RECEIVED DATE,MFG DATE,PORT,TOTAL DUTY,\"TOTAL DUTY, TAXES, FEES & PENALTIES\",LIQUIDATION DATE,TOTAL ENTERED VALUE,MPF,CONVERSION,CUSTOMER NUMBER,REF 1 - INVOICE NUMBER,REF 2 - ORDER NUMBER,REF 3 - DEPT NO,INVOICE LINE - COUNTRY ORIGIN CODE,INVOICE LINE - COUNTRY EXPORT CODE,CD,SKU,STYLE,COLOR,SIZE,EXTERNAL PART,HTS,DESCRIPTION,UNITS,YIELD,RECEIPT QTY,QTY,AVAILABLE QTY,QTY 2,DUTY VALUE 1,DUTY VALUE 2,DUTY VALUE 3,DUTY VALUE 4,RATE 1,RATE 2,RATE 3,RATE 4,DUTY EACH,COMPUTE CODE,STATUS,OCEAN INDICATOR,INVOICE LINE - CUSTOMS LINE NUMBER,HTS DUTY,HTS ENTERED VALUE,HTS QTY,HTS VALUE,UNITS 2,HTS2,HTS3,HTS4,TOTAL TAXES,INVOICE TARIFF - SPI - PRIMARY,ENTRY SUMMARY LINE COUNT,MULTIPLE TARIFF?\n" +
            "ent-1,,,,,,0.0,,,,,HENNE,123456,PO-A,,,,,,part-A,,,,, - ,,1,,0.0,0.0,,,,,,,,,,,7,,,,5.55,,,,,,,,,,,N\n"
    end
  end

  describe "run" do
    it "runs a report with provided dates" do
      expect(subject).to receive(:write_report_to_builder).with(instance_of(subject.builder("csv").class), Date.new(2016, 1, 1).beginning_of_day, Date.new(2016, 12, 31).end_of_day).and_call_original

      subject.run({"email_to"=>["a@b.com"], "start_date"=>"2016-01-01", "end_date"=>"2016-12-31"})

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com']
      expect(mail.subject).to eq "H&M Drawback Import Report"
      expect(mail.body).to include ERB::Util.html_escape("Your H&amp;M Drawback Import Report for 01/01/2016 - 12/31/2016 is attached.".html_safe)
      expect(mail.attachments.length).to eq(1)
      att = mail.attachments[0]
      expect(att.filename).to eq "hm_drawback_import_20160101_20161231.csv"
    end

    it "runs a report with defaulted dates" do
      current_date = Date.new(2018, 10, 15)

      expect(subject).to receive(:write_report_to_builder).with(instance_of(subject.builder("csv").class), Date.new(2018, 1, 1).beginning_of_day, Date.new(2018, 3, 31).end_of_day).and_call_original

      Timecop.freeze(current_date) do
        subject.run({"email_to"=>["a@b.com"]})
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.body).to include ERB::Util.html_escape("Your H&amp;M Drawback Import Report for 01/01/2018 - 03/31/2018 is attached.".html_safe)
      expect(mail.attachments.length).to eq(1)
      att = mail.attachments[0]
      expect(att.filename).to eq "hm_drawback_import_20180101_20180331.csv"
    end

    it "raises error when email addresses not provided" do
      expect { subject.run({}) }.to raise_error("An email_to setting containing an array of email addresses must be provided.")
    end

    it "raises error when email addresses are not an array" do
      expect { subject.run({"email_to"=>"a@b.com"}) }.to raise_error("An email_to setting containing an array of email addresses must be provided.")
    end
  end

end