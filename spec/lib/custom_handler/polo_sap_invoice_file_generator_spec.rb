require 'spec_helper'
require 'spreadsheet'

describe OpenChain::CustomHandler::PoloSapInvoiceFileGenerator do

  before :each do
    @gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
    @api_client = double("ProductApiClient")
    @gen.stub(:api_client).and_return @api_client
    @api_client.stub(:find_by_uid).and_return({'product'=>{'classifications' => []}})
    stub_xml_files @gen
    
    @entry = Factory(:entry, :total_duty_gst => BigDecimal.new("10.99"), :entry_number => '123456789', :total_duty=> BigDecimal.new("5.99"), :total_gst => BigDecimal.new("5.00"), :importer_tax_id => '806167003RM0001')
    @commercial_invoice = Factory(:commercial_invoice, :invoice_number => "INV#", :entry => @entry)
    @cil =  Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>"1234-1", :quantity=> BigDecimal.new("10"))
    @tariff_line = @cil.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))
    @tariff_line2 = @cil.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("1.99"))

    @broker_invoice = Factory(:broker_invoice, :entry => @entry, :invoice_date => Date.new(2013,06,01), :invoice_number => 'INV#')
    @broker_invoice_line1 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("5.00"))
    @broker_invoice_line2 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("4.00"))
    @broker_invoice_line3 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("-1.00"))

    @profit_center = DataCrossReference.create!(:cross_reference_type=>'profit_center', :key=>'ABC', :value=>'Profit')

    @tradecard_invoice = Factory(:commercial_invoice, vendor_name: "Tradecard", invoice_number: @commercial_invoice.invoice_number)
    @tradecard_line = Factory(:commercial_invoice_line, :commercial_invoice => @tradecard_invoice, :part_number => 'ABCDEFG', :po_number=>"471234-1", :quantity=> BigDecimal.new("100"))
  end

  def get_workbook_sheet attachment
    wb = Spreadsheet.open(decode_attachment_to_string(attachment))
    wb.worksheet 0
  end

  def decode_attachment_to_string attachment
    StringIO.new(attachment.read)
  end

  def make_sap_po 
    # set the entry to have an SAP PO
    @entry.update_attributes(:po_numbers=>"A\n47")
    @cil.update_attributes(:po_number=>"47#{@cil.po_number}")
  end

  def stub_xml_files gen
    @xml_files = []
    # Capture the xml file output from an ftp (also prevents actual ftp calls from happening in tests)
    gen.stub(:ftp_file) do |f|
      f.rewind
      xml_file = {}
      xml_file[:name] = f.original_filename
      xml_file[:contents] = f.read
      @xml_files << xml_file
    end
  end

  def xp_t doc, xpath
    REXML::XPath.first(doc, xpath).try(:text)
  end

  def xp_m doc, xpath
    REXML::XPath.match(doc, xpath)
  end

  context :generate_and_send_invoices do
  
    context :MM_Invoices do
      before :each do 
        make_sap_po
      end

      it "should generate and email an MM excel file for RL Canada and ftp an MM xml file for non-set / non-prepack invoices" do
        time = Time.zone.now

        @gen.generate_and_send_invoices :rl_canada, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        job.should_not be_nil
        job.start_time.to_i.should == time.to_i
        # Shouldn't be more than 5 seconds from export job "end time"
        (Time.zone.now.to_i - job.end_time.to_i).should <= 5
        job.successful.should be_true
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
        job.attachments.length.should == 2
        job.attachments.first.attached_file_name.should == "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xls"
        job.attachments.second.attached_file_name.should == "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xml"

        mail = ActionMailer::Base.deliveries.pop
        mail.should_not be_nil
        mail.to.should == ["joanne.pauta@ralphlauren.com", "james.moultray@ralphlauren.com", "dean.mark@ralphlauren.com", "accounting-ca@vandegriftinc.com"]
        mail.subject.should == "[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}"
        mail.body.raw_source.should include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xls"]
        at.should_not be_nil

        sheet = get_workbook_sheet at
        sheet.name.should == "MMGL"
        # Verify the invoice header information
        header = ["X", @broker_invoice.invoice_date.strftime("%Y%m%d"), @broker_invoice.invoice_number, '1017', '100023825', 'CAD', BigDecimal.new("18.99"), nil, '0001', job.start_time.strftime("%Y%m%d"), @broker_invoice.entry.entry_number, "V"]
        sheet.row(1)[0, 12].should == header

        # Verify the commercial invoice information (it should strip the sap line from the value)
        po, line = @gen.split_sap_po_line_number(@cil.po_number)
        inv_row = ["1", po, line, @tariff_line.duty_amount + @tariff_line2.duty_amount, @cil.quantity, "ZDTY", nil]
        sheet.row(1)[12, 7].should == inv_row

        # Verify the broker invoice information
        # First line is GST
        brok_inv_rows = [
          ["1", "14311000", @entry.total_gst, "S", "1017", "GST", "19999999"],
          ["2", "52111200", @broker_invoice_line1.charge_amount, "S", "1017", @broker_invoice_line1.charge_description, @profit_center.value],
          ["3", "52111200", @broker_invoice_line2.charge_amount, "S", "1017", @broker_invoice_line2.charge_description, @profit_center.value],
          ["4", "52111200", @broker_invoice_line3.charge_amount.abs, "H", "1017", @broker_invoice_line3.charge_description, @profit_center.value]
        ]
        sheet.row(1)[19, 7].should == brok_inv_rows[0]

        # Rest of the lines are the actual broker charges
        sheet.row(2)[19, 7].should == brok_inv_rows[1]
        sheet.row(3)[19, 7].should == brok_inv_rows[2]
        sheet.row(4)[19, 7].should == brok_inv_rows[3]

        # Now we need to verify the XML document structure
        expect(@xml_files).to have(1).item
        @xml_files[0][:name].should == "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xml"
        d = REXML::Document.new @xml_files[0][:contents]
        d.root.name.should eq "Invoices"
        expect(xp_m(d, '/Invoices/Invoice')).to have(1).item
        expect(xp_m(d, '/Invoices/Invoice/HeaderData')).to have(1).item
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/Indicator')).to eq header[0]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DocumentType')).to eq "RE"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DocumentDate')).to eq header[1]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/PostingDate')).to eq header[9]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/Reference')).to eq header[2]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/CompanyCode')).to eq header[3]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DifferentInvoicingParty')).to eq header[4]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/CurrencyCode')).to eq header[5]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/Amount')).to eq header[6].to_s
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/PaymentTerms')).to eq header[8]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/BaseLineDate')).to eq header[9]

        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData')).to have(1).item
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/InvoiceDocumentNumber')).to eq inv_row[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq po
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq line
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq inv_row[3].to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Currency')).to eq header[5]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq inv_row[4].to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/ConditionType')).to eq inv_row[5]

        expect(xp_m(d, '/Invoices/Invoice/GLAccounts/GLAccountData')).to have(brok_inv_rows.length).items
        brok_inv_rows.each_with_index do |row, x|
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/GLVendorCustomer")).to eq row[1]
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/Amount")).to eq row[2].to_s
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/DocumentType")).to eq row[3]
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/CompanyCode")).to eq row[4]
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/LineItemText")).to eq row[5]
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/ProfitCenter")).to eq row[6]
        end
      end

      it "should generate and email an MM excel file for a non-SAP PO that's been migrated" do
        @entry.update_attributes(:po_numbers=>"A")
        @po_xref = DataCrossReference.create!(:cross_reference_type=>'po_to_brand', :key=>'A', :value=>'ABC')

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        # Just verify that an MM invoice was generated.  There are no data differences between SAP / non-SAP invoices in the MM format.
        job = ExportJob.all.first
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      end

      it "should create an MM invoice, skip GST line if GST amount is 0, and skip duty charge lines in commercial invoices" do
        # Make this entry for an SAP PO
        @entry.update_attributes(:total_gst => BigDecimal.new(0))
        @broker_invoice_line1.update_attributes(:charge_type => "D")


        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        job = ExportJob.all.first
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE

        mail = ActionMailer::Base.deliveries.pop
        mail.should_not be_nil

        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/GLAccounts/GLAccountData')).to have(2).items
        expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[1]/Amount")).to eq @broker_invoice_line2.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[2]/Amount")).to eq @broker_invoice_line3.charge_amount.abs.to_s
      end

      it "should use different GL account for Brokerage fees" do
        @broker_invoice_line1.update_attributes(:charge_code => "22")

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[2]/GLVendorCustomer")).to eq "52111300"
      end

      it "should use tradecard invoice line quantity for Sets and combine like invoice lines" do
        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        gen.should_receive(:api_client).and_return api_client
        
        product_json = {'product' => {'classifications' => [{"class_cntry_iso" => "CA", "*cf_131" => "CS"}]}}

        api_client.should_receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_return product_json

        inv_line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>@cil.po_number, :quantity=> BigDecimal.new("20"))
        inv_line_2_tariff = inv_line_2.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))
        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files).to have(1).item

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData')).to have(1).item
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount + inv_line_2_tariff.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @tradecard_line.quantity.to_s
      end

      it "should use tradecard invoice line quantity for prepacks and combine like invoice lines" do
        @tradecard_line.update_attributes :unit_of_measure => "AS"
        inv_line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>@cil.po_number, :quantity=> BigDecimal.new("20"))
        inv_line_2_tariff = inv_line_2.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files).to have(1).item

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData')).to have(1).item
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount + inv_line_2_tariff.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @tradecard_line.quantity.to_s
      end

      it "should use entry quantity and combine lines for non-prepack / non-set lines" do
        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        gen.should_receive(:api_client).and_return api_client
        
        product_json = {'product' => {'classifications' => [{"class_cntry_iso" => "CA", "*cf_131" => ""}]}}

        api_client.should_receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_return product_json

        inv_line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>@cil.po_number, :quantity=> BigDecimal.new("20"))
        inv_line_2_tariff = inv_line_2.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))

        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files).to have(1).item

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData')).to have(1).items
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount + inv_line_2_tariff.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq (@cil.quantity + inv_line_2.quantity).to_s
      end

      it "should use entry quantity and email Joanne Pauta with non-conformant line report for missing products" do
        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        gen.should_receive(:api_client).and_return api_client
        
        # API 404's on missing product
        api_client.should_receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_raise OpenChain::Api::ApiClient::ApiError.new(404, {'errors'=>['Not Found']})
        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files).to have(1).item

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData')).to have(1).items
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @cil.quantity.to_s

        job = ExportJob.all.first
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE

        mail = ActionMailer::Base.deliveries.pop
        mail.should_not be_nil
        mail.to.should == ["joanne.pauta@ralphlauren.com", "james.moultray@ralphlauren.com", "dean.mark@ralphlauren.com", "accounting-ca@vandegriftinc.com"]
        mail.subject.should == "[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}"
        mail.body.raw_source.should include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice_Exceptions.xls"]
        at.should_not be_nil

        sheet = get_workbook_sheet at
        sheet.name.should == "MMGL Exceptions"
        sheet.row(0).should == ["Entry #", "Commercial Invoice #", "PO #", "SAP Line #", "Error"]
        sheet.row(1).should == [@entry.entry_number, @commercial_invoice.invoice_number, @cil.po_number.split("-")[0], (@cil.po_number.split("-")[1] + "0"), "No VFI Track product found for style #{@cil.part_number}."]
      end

      it "should use entry quantity and email Joanne Pauta with non-conformant line report for missing Tradecard lines" do
        @tradecard_line.destroy

        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        gen.should_receive(:api_client).and_return api_client
        product_json = {'product' => {'classifications' => [{"class_cntry_iso" => "CA", "*cf_131" => "CS"}]}}
        
        # API 404's on missing product
        api_client.should_receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_return product_json
        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files).to have(1).item

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData')).to have(1).items
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @cil.quantity.to_s

        job = ExportJob.all.first
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE

        mail = ActionMailer::Base.deliveries.pop
        mail.should_not be_nil
        mail.to.should == ["joanne.pauta@ralphlauren.com", "james.moultray@ralphlauren.com", "dean.mark@ralphlauren.com", "accounting-ca@vandegriftinc.com"]
        mail.subject.should == "[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}"
        mail.body.raw_source.should include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice_Exceptions.xls"]
        at.should_not be_nil

        sheet = get_workbook_sheet at
        sheet.name.should == "MMGL Exceptions"
        sheet.row(0).should == ["Entry #", "Commercial Invoice #", "PO #", "SAP Line #", "Error"]
        sheet.row(1).should == [@entry.entry_number, @commercial_invoice.invoice_number, @cil.po_number.split("-")[0], (@cil.po_number.split("-")[1] + "0"), "No Tradecard Invoice line found for PO # #{ @cil.po_number.split("-")[0]} / SAP Line #{(@cil.po_number.split("-")[1] + "0")}"]
      end

      it "falls back to PO to find SAP Line number" do
        @tradecard_invoice.destroy
        @cil.update_attributes! po_number: "ABCD"
        make_sap_po

        order_line = Factory(:order_line, line_number: "0020", product: Factory(:product, unique_identifier: "#{@entry.importer_tax_id}-#{@cil.part_number}"),
          order: Factory(:order, order_number: "#{@entry.importer_tax_id}-#{@cil.po_number}")
        )

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq order_line.line_number.to_s
      end

      context "multiple invoices same entry mm/gl split" do
        it "should know if an entry has been sent already during the same generation and send FFI format for second" do
          # create a second broker invoice for the same entry, and make sure it's output in FFI format
          # this also tests making multiple export jobs and attaching multiple files to the email

          @broker_invoice2 = Factory(:broker_invoice, :entry => @entry, :invoice_date => Date.new(2013,06,02), :invoice_number => 'INV2')
          @broker_invoice2_line1 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("5.00"))
          
          @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice, @broker_invoice2]

          job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE).first
          job.should_not be_nil

          job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE).first
          job.should_not be_nil

          expect(@xml_files).to have(2).items
          expect(@xml_files[0][:name]).to eq "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xml"
          expect(@xml_files[1][:name]).to eq "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xml"

          d = REXML::Document.new @xml_files[0][:contents]
          expect(xp_t(d, "/Invoices/Invoice/HeaderData/Reference")).to eq @broker_invoice.invoice_number

          # Invoice # isn't in the FFI file, so just use what's there and the document structure confirms
          # it's actually an FFI file
          d = REXML::Document.new @xml_files[1][:contents]
          expect(xp_t(d, "/Invoices/Invoice/HeaderData/REFERENCE")).to eq @broker_invoice2.invoice_number
        end
      end

      it "should generate and email an MM excel file for Club Monaco" do
        time = Time.zone.now

        @gen.generate_and_send_invoices :club_monaco, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        mail = ActionMailer::Base.deliveries.pop
        expect(mail).to_not be_nil
        expect(mail.to).to eq ["joanne.pauta@ralphlauren.com", "matthew.dennis@ralphlauren.com", "jude.belas@ralphlauren.com", "robert.helm@ralphlauren.com", "accounting-ca@vandegriftinc.com"]
        mail.subject.should == "[VFI Track] Vandegrift, Inc. Club Monaco Invoices for #{job.start_time.strftime("%m/%d/%Y")}"
        mail.body.raw_source.should include "An MM and/or FFI invoice file is attached for Club Monaco for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xls"]
        at.should_not be_nil

        sheet = get_workbook_sheet at
        sheet.name.should == "MMGL"
        # We only need to validate the file differences between CM and RL CA
        # Which is the company code and unallocated profit center differences

        expect(sheet.row(1)[3]).to eq "1710"
        expect(sheet.row(1)[23]).to eq "1710"
        # First line is always GST, which is always the unallocated profit center
        expect(sheet.row(1)[25]).to eq "20399999"
        expect(sheet.row(2)[25]).to eq @profit_center.value
      end
    end

    context :FFI_Invoices do

      it "should generate an FFI invoice for non-deployed brands" do
        # By virtue of not setting up the entry/invoice line PO# as an SAP PO and not setting up a brand x-ref
        # we'll get an FFI format output
        # This also means we'll be using the 199.. profit center for everything

        # Make the first charge an HST charge (verify the correct g/l account is used for that)
        @broker_invoice_line1.update_attributes(:charge_code=>"250", :charge_description=>"123456789012345678901234567890123456789012345678901")
        time = Time.zone.now

        @gen.generate_and_send_invoices :rl_canada, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        job.should_not be_nil
        job.start_time.to_i.should == time.to_i
        # Shouldn't be more than 5 seconds from export job "end time"
        (Time.zone.now.to_i - job.end_time.to_i).should <= 5
        job.successful.should be_true
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE
        job.attachments.length.should == 2
        job.attachments.first.attached_file_name.should == "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xls"
        job.attachments.second.attached_file_name.should == "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xml"

        mail = ActionMailer::Base.deliveries.pop
        mail.should_not be_nil
        mail.subject.should == "[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}"
        mail.body.raw_source.should include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        mail.attachments.should have(1).item

        mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xls"].should_not be_nil

        sheet = get_workbook_sheet mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xls"]
        sheet.name.should == "FFI"
        now = job.start_time.strftime("%m/%d/%Y")
        rows = []
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "31", "100023825", nil, BigDecimal.new("18.99"), "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "49999999", nil, @entry.entry_number, nil]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "23101230", nil, @entry.total_duty, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, "Duty"]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "14311000", nil, @entry.total_gst, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, "GST"]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "14311000", nil, @broker_invoice_line1.charge_amount, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, @broker_invoice_line1.charge_description[0, 50]]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "23101900", nil, @broker_invoice_line2.charge_amount, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, @broker_invoice_line2.charge_description[0, 50]]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "23101900", nil, @broker_invoice_line3.charge_amount, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, @broker_invoice_line3.charge_description[0, 50]]

        sheet.row(1).should == rows[0]
        sheet.row(2).should == rows[1]
        sheet.row(3).should == rows[2]
        sheet.row(4).should == rows[3]
        sheet.row(5).should == rows[4]
        sheet.row(6).should == rows[5]

        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        h = rows[0]
        expect(xp_m(d, '/Invoices/Invoice/HeaderData')).to have(1).item
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/COMPANYCODE')).to eq h[2]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DOCUMENTTYPE')).to eq h[1]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DOCUMENTDATE')).to eq h[0]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/POSTINGDATE')).to eq h[3]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/REFERENCE')).to eq h[8]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq h[10]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq h[12].to_s
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/CURRENCYCODE')).to eq h[4]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/BASELINEDATE')).to eq h[3]


        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData')).to have(5).items

        rows[1..-1].each_with_index do |r, x|
          expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[#{x+1}]/COMPANYCODE")).to eq r[2]
          expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[#{x+1}]/GLVENDORCUSTOMER")).to eq r[10]
          expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[#{x+1}]/CreditDebitIndicator")).to eq "S"
          expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[#{x+1}]/AMOUNT")).to eq r[12].to_s
          expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[#{x+1}]/PROFITCENTER")).to eq r[24]
        end
      end

      it "should generate an FFI invoice for non-deployed brands for Club Monaco" do
        # All that we need to check here is the differences between rl ca and club monaco
        time = Time.zone.now
        @gen.generate_and_send_invoices :club_monaco, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        job.should_not be_nil
        mail = ActionMailer::Base.deliveries.pop

        sheet = get_workbook_sheet mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xls"]
        # The only differences here should be the company code and the profit centers utilized
        expect(sheet.row(1)[2]).to eq "1710"
        expect(sheet.row(2)[24]).to eq "20399999"
      end

      it "should use unallocated profit center for CM invoices on HST/GST Lines" do
        @broker_invoice_line1.update_attributes! charge_code: "250"
        @gen.stub(:find_profit_center).and_return "profit_center"

        # All that we need to check here is the differences between rl ca and club monaco
        time = Time.zone.now
        @gen.generate_and_send_invoices :club_monaco, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        job.should_not be_nil
        mail = ActionMailer::Base.deliveries.pop

        sheet = get_workbook_sheet mail.attachments["Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xls"]
        # The only differences here should be the company code and the profit centers utilized
        expect(sheet.row(1)[2]).to eq "1710"
        expect(sheet.row(2)[24]).to eq "profit_center"
        expect(sheet.row(4)[24]).to eq "20399999"
        expect(sheet.row(4)[27]).to eq @broker_invoice_line1.charge_description
      end

      it "should generate an FFI invoice for converted legacy PO's missing profit center links" do
        po_to_brand_xref = DataCrossReference.create!(:cross_reference_type=>'po_to_brand', :key=>'A', :value=>'NO PROFIT CENTER FOR YOU')

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        job.should_not be_nil
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE
        now = job.start_time.strftime("%m/%d/%Y")

        # Verify the profit center is the 199.. one (aside from the FFI invoice instead of MM, that's the only thing to look out for here)
        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/PROFITCENTER")).to eq "19999999"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[4]/PROFITCENTER")).to eq "19999999"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[5]/PROFITCENTER")).to eq "19999999"
      end

      it "should generate an FFI invoice for SAP PO's that have already had an invoice sent" do
        make_sap_po

        @gen.stub(:previously_invoiced?).with(@entry).and_return true

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        job = ExportJob.all.first
        job.should_not be_nil
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE

        mail = ActionMailer::Base.deliveries.pop
        sheet = get_workbook_sheet mail.attachments.first
        now = job.start_time.strftime("%m/%d/%Y")

        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        # Because we've sent an invoice for the entry already, we don't include duty or GST in the total or in the charge lines
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq "100023825"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq BigDecimal.new("8.00").to_s

        # Since this is an SAP PO, we should be using the actual SAP profit center from the xref
        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData')).to have(3).items
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/AMOUNT")).to eq @broker_invoice_line1.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/AMOUNT")).to eq @broker_invoice_line2.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/AMOUNT")).to eq @broker_invoice_line3.charge_amount.to_s
      end

      it "should skip GST/Duty lines for entries previously invoiced using the FFI interface" do
        # Just like we skip the gst/duty lines for SAP entries we've already sent via MM, we need to do the
        # same when we've sent the entry previously via FFI interface

        @gen.stub(:previously_invoiced?).with(@entry).and_return true

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        job = ExportJob.all.first
        job.should_not be_nil
        job.export_type.should == ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE

        expect(@xml_files).to have(1).item
        d = REXML::Document.new @xml_files[0][:contents]
        # Because we've sent an invoice for the entry already, we don't include duty or GST in the total or in the charge lines
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq "100023825"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq BigDecimal.new("8.00").to_s

        # Since this is an SAP PO, we should be using the actual SAP profit center from the xref
        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData')).to have(3).items
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/AMOUNT")).to eq @broker_invoice_line1.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/AMOUNT")).to eq @broker_invoice_line2.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/AMOUNT")).to eq @broker_invoice_line3.charge_amount.to_s
      end

      it "should generate a credit FFI invoice" do
        # Skip the duty/gst lines so only the invoice lines are accounted for, this is how it'll end up being invoiced
        # for real anyway.
        @gen.stub(:previously_invoiced?).with(@entry).and_return true
        @broker_invoice_line1.update_attributes :charge_amount => BigDecimal("-5.00")
        @broker_invoice_line2.update_attributes :charge_amount => BigDecimal("-4.00")

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        mail = ActionMailer::Base.deliveries.pop
        sheet = get_workbook_sheet mail.attachments.first
        now = ExportJob.all.first.start_time.strftime("%m/%d/%Y")

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DOCUMENTTYPE')).to eq "KG"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq "100023825"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq BigDecimal.new("10.00").to_s

        # Since this is an SAP PO, we should be using the actual SAP profit center from the xref
        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData')).to have(3).items
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/CreditDebitIndicator")).to eq "H"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/AMOUNT")).to eq @broker_invoice_line1.charge_amount.abs.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/CreditDebitIndicator")).to eq "H"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/AMOUNT")).to eq @broker_invoice_line2.charge_amount.abs.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/CreditDebitIndicator")).to eq "H"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/AMOUNT")).to eq @broker_invoice_line3.charge_amount.abs.to_s
      end
    end

    context :multiple_invoices_same_entry do
      it "should know if an entry has been sent already during the same generation and send FFI format for second" do
        # create a second broker invoice for the same entry, and make sure it's output in FFI format
        # this also tests making multiple export jobs and attaching multiple files to the email
        make_sap_po

        @broker_invoice2 = Factory(:broker_invoice, :entry => @entry, :invoice_date => Date.new(2013,06,01), :invoice_number => 'INV2')
        @broker_invoice2_line1 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("5.00"))
        
        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice, @broker_invoice2]

        job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE).first
        job.should_not be_nil

        job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE).first
        job.should_not be_nil

        expect(@xml_files).to have(2).items
        expect(@xml_files[0][:name]).to eq "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_MM_Invoice.xml"
        expect(@xml_files[1][:name]).to eq "Vandegrift_#{job.start_time.strftime("%Y%m%d")}_FFI_Invoice.xml"

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, "/Invoices/Invoice/HeaderData/Reference")).to eq @broker_invoice.invoice_number

        # Invoice # isn't in the FFI file, so just use what's there and the document structure confirms
        # it's actually an FFI file
        d = REXML::Document.new @xml_files[1][:contents]
        expect(xp_t(d, "/Invoices/Invoice/HeaderData/REFERENCE")).to eq @broker_invoice2.invoice_number
      end
    end
  end

  context :previously_invoiced? do
    it "should identify an entry as not having been invoiced" do
      @gen.previously_invoiced?(@entry).should be_false
    end

    it "should not identify an entry as having been invoiced if the export job is not successful" do
      j = ExportJob.new
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      @gen.previously_invoiced?(@entry).should be_false
    end

    it "should identify an entry as being invoiced if it has a successful export job associated with it" do
      j = ExportJob.new
      j.successful = true
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      @gen.previously_invoiced?(@entry).should be_true
    end
  end

  context :find_broker_invoices do
    it "should find broker invoices for RL Canada after June 1, 2013 that have not been succssfully invoiced" do
      # the default invoice should be found
      invoices = @gen.find_broker_invoices :rl_canada
      expect(invoices.first.id).to eq @broker_invoice.id
    end

    it "should find broker invoices for Club Monaco after May 23, 2014 that have not been succssfully invoiced" do
      @broker_invoice.update_attributes! invoice_date: '2014-05-24'
      @broker_invoice.entry.update_attributes! importer_tax_id: '866806458RM0001'

      # the default invoice should be found
      invoices = @gen.find_broker_invoices :club_monaco
      expect(invoices.first.id).to eq @broker_invoice.id
    end

    it "should not find invoiced invoices" do
      j = ExportJob.new
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.successful = true
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      expect(@gen.find_broker_invoices(:rl_canada)).to have(0).items
    end

    it "should not find RL Canada invoices prior to June 1, 2013" do
      @broker_invoice.update_attributes(:invoice_date => Date.new(2013, 5, 31))
      expect(@gen.find_broker_invoices(:rl_canada)).to have(0).items
    end

    it "should not find Club Monaco invoices prior to May 23, 2014" do
      @broker_invoice.update_attributes(:invoice_date => Date.new(2014, 5, 22))
      expect(@gen.find_broker_invoices(:club_monaco)).to have(0).items
    end

    it "should use custom_where if supplied to constructor" do
      # Set the date prior to the cut-off so we know we're absolutely overriding the 
      # standard where clauses
      @broker_invoice.update_attributes(:invoice_date => Date.new(2012, 1, 1))
      generator = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new :prod, {:id => @broker_invoice.id}

      # Can use nil, because the company symbol passed in here is only used when creating a  "standard" query
      # we're overriding that w/ the custom clause
      expect(generator.find_broker_invoices(:rl_canada).first.id).to eq @broker_invoice.id
    end

    it "does not include invoices for entries with failing business rules" do
      @entry.business_validation_results.create! state: 'Fail'
      expect(@gen.find_broker_invoices(:rl_canada)).to have(0).items
    end
  end

  context :find_generate_and_send_invoices do
    it "should run in eastern timezone, call find invoices, and generate" do
      # everything done in the generation and find invoices is already tested..so just make sure this method just
      # calls the right things (yes, I'm pretty much just mocking every call.)
      zone = double("zone")
      now = double("now")

      Time.stub(:use_zone).with("Eastern Time (US & Canada)").and_yield
      Time.stub(:zone).and_return zone
      zone.stub(:now).and_return now
      @gen.should_receive(:find_broker_invoices).with(:rl_canada).and_return([@broker_invoice])
      @gen.should_receive(:find_broker_invoices).with(:club_monaco).and_return([])
      @gen.should_receive(:generate_and_send_invoices).with(:rl_canada, now, [@broker_invoice])
      @gen.should_receive(:generate_and_send_invoices).with(:club_monaco, now, [])

      @gen.find_generate_and_send_invoices
    end
  end

  context :run_schedulable do
    it "should instantiate a new generator and run the process" do
      # The only thing this method does is instantiate a new generator and call a method..just make sure it's doing that
      OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.any_instance.should_receive(:find_generate_and_send_invoices)
      OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.run_schedulable {}
    end
  end

  context :exception_handling do
    it "should log an exception containing a spreadsheet with all errors encountered while building the invoice files" do
      # hook into a method in generate_invoice_output and have it raise an error so we can test error handling
      # during the invoice file generation
      @gen.should_receive(:determine_invoice_output_format).and_raise "Error to log."
      sheet = nil
      StandardError.any_instance.should_receive(:log_me) do |messages, file_paths|
        messages[0].should == "See attached spreadsheet for full list of invoice numbers that could not be generated."
        sheet = Spreadsheet.open(file_paths[0]).worksheet 0
      end

      @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

      sheet.row(1)[0].should == @broker_invoice.invoice_number
      sheet.row(1)[1].should == "Error to log."
      # This is the backtrace, so just make sure this looks somewhat like a backtrace should
      sheet.row(1)[2].should =~ /lib\/open_chain\/custom_handler\/polo_sap_invoice_file_generator\.rb:\d+/
    end
  end

  describe "ftp_credentials" do
    it "uses ftp2" do
      expect(@gen.ftp_credentials).to eq server: "ftp2.vandegriftinc.com", username: "VFITRACK", password: "RL2VFftp", folder: "to_ecs/Ralph_Lauren/sap_invoices"
    end
  end
end
