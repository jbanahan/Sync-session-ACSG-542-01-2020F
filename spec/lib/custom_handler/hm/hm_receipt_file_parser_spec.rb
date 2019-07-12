describe OpenChain::CustomHandler::Hm::HmReceiptFileParser do
  let(:user) { Factory(:user) }
  let(:custom_file) { double "custom file "}

  describe 'can_view?' do
    let(:subject) { described_class.new(nil) }
    let(:ms) { stub_master_setup }

    it "allow users in group" do
      expect(user).to receive(:in_group?).with('hm_receipt_file_upload').and_return true
      expect(subject.can_view? user).to eq true
    end

    it "blocks users not in group" do
      expect(user).to receive(:in_group?).with('hm_receipt_file_upload').and_return false
      expect(subject.can_view? user).to eq false
    end
  end

  describe 'valid_file?' do
    it "allows expected file extensions and forbids weird ones" do
      expect(described_class.valid_file? 'abc.CSV').to eq true
      expect(described_class.valid_file? 'abc.csv').to eq true
      expect(described_class.valid_file? 'def.XLS').to eq true
      expect(described_class.valid_file? 'def.xls').to eq true
      expect(described_class.valid_file? 'ghi.XLSX').to eq true
      expect(described_class.valid_file? 'ghi.xlsx').to eq true
      expect(described_class.valid_file? 'xls.txt').to eq false
      expect(described_class.valid_file? 'abc.').to eq false
    end
  end

  describe "process" do
    let!(:importer) { Factory(:company, system_code:'HENNE') }
    let!(:master_setup) { stub_master_setup_request_host }
    let(:subject) { described_class.new(custom_file) }
    let(:file_reader) { double "dummy reader" }
    let(:header_row) { ["LOCATION_CODE","DELIVERY_DATE","ECC_VARIANT_CODE","ORDER_NUMBER","PRODUCTION_COUNTRY","QUANTITY","SKU","Season"] }
    before(:each) {
      allow(custom_file).to receive(:attached_file_name).and_return "file.xls"
    }

    it "processes file" do
      row_1 = ["W180","6/13/2016","279635006164001","114690","South Korea","10","0279635006001","164"]
      row_2 = ["W181","6/14/2016","200585007164006","175449","China","11","0200585007006","165"]
      blank_row = ["", "", "", "", "", "", "", ""]

      entry = Entry.new(importer:importer)
      invoice_1 = entry.commercial_invoices.build(invoice_number:'114690')
      invoice_line_1 = invoice_1.commercial_invoice_lines.build(part_number:'0279635')
      tariff_1_a = invoice_line_1.commercial_invoice_tariffs.build
      # This tariff will be ignored.
      tariff_1_b = invoice_line_1.commercial_invoice_tariffs.build
      invoice_2 = entry.commercial_invoices.build(invoice_number:'175449')
      invoice_line_2 = invoice_2.commercial_invoice_lines.build(part_number:'0200585')
      tariff_2 = invoice_line_2.commercial_invoice_tariffs.build
      entry.save!

      product_xref_1 = HmProductXref.create(sku:'0279635006001')
      product_xref_2 = HmProductXref.create(sku:'0200585007006')

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_1).and_yield(blank_row).and_yield(row_2)
      allow(MasterSetup).to receive(:test_env?).and_return(false)

      Timecop.freeze(Date.new(2019,1,2)) do
        subject.process user
      end

      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "H&M Receipt File processing for 'file.xls' is complete."

      expect(HmReceiptLine.count).to eq 2

      rec_1 = HmReceiptLine.where(order_number:"114690", sku:"0279635006001", delivery_date:Date.new(2016,6,13)).first
      expect(rec_1).not_to be_nil
      expect(rec_1.location_code).to eq "W180"
      expect(rec_1.ecc_variant_code).to eq "279635006164001"
      expect(rec_1.production_country).to eq "South Korea"
      expect(rec_1.quantity).to eq 10
      expect(rec_1.season).to eq "164"

      rec_2 = HmReceiptLine.where(order_number:"175449", sku:"0200585007006", delivery_date:Date.new(2016,6,14)).first
      expect(rec_2).not_to be_nil
      expect(rec_2.location_code).to eq "W181"
      expect(rec_2.ecc_variant_code).to eq "200585007164006"
      expect(rec_2.production_country).to eq "China"
      expect(rec_2.quantity).to eq 11
      expect(rec_2.season).to eq "165"
    end

    it "handles missing values and bad dates" do
      Factory(:mailing_list, name:'Testing', system_code:'HmReceiptFileParserErrors', user:user, email_addresses:"a@b.com, c@d.com")

      row_1 = ["W180"," ","279635006164001"," ","South Korea","10"," ","164"]
      row_2 = ["W182","A/BB/CCCC","279635006164001","114691","South Korea","12","0279635006004","163"]
      row_3 = ["W181","6/14/2016","200585007164006","175449","China","bad number","0200585007006","165"]
      row_4 = ["W183","6/14/2017","200585007164006","175449","China","5","0200585007007","165"]
      row_5 = ["W184","6/14/2017","200585007164006","175450","China","5","0200585007008","165"]

      entry = Entry.new(importer:importer)
      invoice = entry.commercial_invoices.build(invoice_number:'175449')
      invoice_line = invoice.commercial_invoice_lines.build(part_number:'0200585')
      tariff = invoice_line.commercial_invoice_tariffs.build
      entry.save!
      product_xref = HmProductXref.create(sku:'0200585007006')

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_1).and_yield(row_2).and_yield(row_3).and_yield(row_4).and_yield(row_5)

      subject.process user

      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "H&M Receipt File processing for 'file.xls' is complete.\n\nAn email has been sent to members of the H&M Receipt File Parser Errors mailing list detailing issues encountered during processing of 2 lines."

      expect(HmReceiptLine.count).to eq 3

      rec = HmReceiptLine.where(order_number:"175449", sku:"0200585007006", delivery_date:Date.new(2016,6,14)).first
      expect(rec).not_to be_nil
      expect(rec.quantity).to eq 0

      expect(HmReceiptLine.where(order_number:"175449", sku:"0200585007007").first).not_to be_nil
      expect(HmReceiptLine.where(order_number:"175450", sku:"0200585007008").first).not_to be_nil

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com','c@d.com']
      expect(mail.subject).to eq 'H&M Import Drawback Data: Errors/missing values'
      expect(mail.body).to include ERB::Util.html_escape("Drawback data could not be generated for some file lines. See the attached document for a full list of issues.<br><br>Please contact VFI Track Support at support@vandegriftinc.com with any questions.".html_safe)
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].filename).to eq('errors.txt')
      expect(mail.attachments[0].body).to eq "Line 2: Delivery Date is required and must be in mm/dd/yyyy format.  Order Number is required.  SKU is required.\nLine 3: Delivery Date is required and must be in mm/dd/yyyy format.\n"
    end

    it "handles line-level exceptions" do
      Factory(:mailing_list, name:'Testing', system_code:'HmReceiptFileParserErrors', user:user, email_addresses:"b@a.com, d@c.com")

      row_1 = ["W180","6/13/2016","279635006164001","114690","South Korea","10","0279635006001","164"]

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_1)
      expect(HmReceiptLine).to receive(:where).and_raise("Terrible Exception")

      subject.process user

      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "H&M Receipt File processing for 'file.xls' is complete.\n\nAn email has been sent to members of the H&M Receipt File Parser Errors mailing list detailing issues encountered during processing of 1 line."

      expect(HmReceiptLine.count).to eq 0

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['b@a.com','d@c.com']
      expect(mail.subject).to eq 'H&M Import Drawback Data: Errors/missing values'
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].body).to eq "Line 2: Terrible Exception\n"
    end

    it "raises exception if line-level exception encountered and mailing list not configured" do
      row_1 = ["W180","6/13/2016","279635006164001","114690","South Korea","10","0279635006001","164"]

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_1)
      expect(HmReceiptLine).to receive(:where).and_raise("Terrible Exception")

      expect { subject.process(user) }.to raise_error(RuntimeError, 'H&M Receipt File Parser Errors mailing list not configured.')

      expect(user.messages.length).to eq 0
      expect(HmReceiptLine.count).to eq 0
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "processes file that contains multiple lines matching part number" do
      row_1 = ["W180","6/13/2016","279635006164001","114690","South Korea","10","0279635006001","164"]

      entry = Entry.new(importer:importer)
      invoice_1 = entry.commercial_invoices.build(invoice_number:'114690')
      invoice_line_1 = invoice_1.commercial_invoice_lines.build(part_number:'0279635')
      tariff_1_a = invoice_line_1.commercial_invoice_tariffs.build
      # This tariff will be ignored.
      tariff_1_b = invoice_line_1.commercial_invoice_tariffs.build
      # This line will be ignored.
      invoice_line_2 = invoice_1.commercial_invoice_lines.build(part_number:'0279635')
      tariff_2 = invoice_line_2.commercial_invoice_tariffs.build
      entry.save!

      product_xref_1 = HmProductXref.create(sku:'0279635006001')

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(row_1)

      subject.process user

      expect(HmReceiptLine.count).to eq 1
    end

  end

end