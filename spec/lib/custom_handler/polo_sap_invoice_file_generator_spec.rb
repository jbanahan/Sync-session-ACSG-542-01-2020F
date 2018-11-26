require 'spec_helper'
require 'spreadsheet'

describe OpenChain::CustomHandler::PoloSapInvoiceFileGenerator do

  let (:user) {
    Factory(:user)
  }

  let (:importer) {
    Factory(:importer, fenix_customer_number: "806167003RM0001")
  }

  let! (:rl_canada_list) { 
    MailingList.create! system_code: "sap_billing", name: "SAP Billing", email_addresses: "rl_canada@rl.com", user: user, company: importer
  }

  let! (:club_monaco_list) { 
    MailingList.create! system_code: "sap_billing_2", name: "SAP Billing 2", email_addresses: "club_monaco@rl.com", user: user, company: importer
  }

  let! (:factory_stores_list) { 
    MailingList.create! system_code: "sap_billing_3", name: "SAP Billing 3", email_addresses: "factory_stores@rl.com", user: user, company: importer
  }

  before :each do
    @gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
    @api_client = double("ProductApiClient")
    allow(@gen).to receive(:api_client).and_return @api_client
    allow(@api_client).to receive(:find_by_uid).and_return({'product'=>{'classifications' => []}})
    stub_xml_files @gen

    @importer = importer
    @entry = Factory(:entry, :total_duty_gst => BigDecimal.new("10.99"), :entry_number => '123456789', :total_duty=> BigDecimal.new("5.99"), :total_gst => BigDecimal.new("5.00"), :importer_tax_id => 'BLAHBLAHBLAH', importer: @importer)
    @commercial_invoice = Factory(:commercial_invoice, :invoice_number => "INV#", :entry => @entry)
    @cil =  Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>"1234-1", :quantity=> BigDecimal.new("10"))
    @tariff_line = @cil.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))
    @tariff_line2 = @cil.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("1.99"))

    @broker_invoice = Factory(:broker_invoice, :entry => @entry, :invoice_date => Date.new(2013,06,01), :invoice_number => 'INV#')
    @broker_invoice_line1 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("5.00"))
    @broker_invoice_line2 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("4.00"))
    @broker_invoice_line3 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("-1.00"))

    @profit_center = DataCrossReference.create!(:cross_reference_type=>'profit_center', :key=>'ABC', :value=>'Profit', company_id: @importer.id)

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
    allow(gen).to receive(:ftp_file) do |f|
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

  context "generate_and_send_invoices" do

    context "MM_Invoices" do
      before :each do
        make_sap_po
      end

      it "should generate and email an MM excel file for RL Canada and ftp an MM xml file for non-set / non-prepack invoices" do
        time = Time.zone.now

        @gen.generate_and_send_invoices :rl_canada, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        expect(job).not_to be_nil
        expect(job.start_time.to_i).to eq(time.to_i)
        # Shouldn't be more than 5 seconds from export job "end time"
        expect(Time.zone.now.to_i - job.end_time.to_i).to be <= 5
        expect(job.successful).to be_truthy
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE)
        expect(job.attachments.length).to eq(2)
        expect(job.attachments.first.attached_file_name).to eq("Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")}.xls")
        expect(job.attachments.second.attached_file_name).to eq("Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")}.xml")

        mail = ActionMailer::Base.deliveries.pop
        expect(mail).not_to be_nil
        expect(mail.to).to eq(["rl_canada@rl.com"])
        expect(mail.subject).to eq("[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}")
        expect(mail.body.raw_source).to include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")}.xls"]
        expect(at).not_to be_nil

        sheet = get_workbook_sheet at
        expect(sheet.name).to eq("MMGL")
        # Verify the invoice header information
        header = ["X", @broker_invoice.invoice_date.strftime("%Y%m%d"), @broker_invoice.invoice_number, '1017', '100023825', 'CAD', BigDecimal.new("18.99"), nil, '0001', job.start_time.strftime("%Y%m%d"), @broker_invoice.entry.entry_number, "V"]
        expect(sheet.row(1)[0, 12]).to eq(header)

        # Verify the commercial invoice information (it should strip the sap line from the value)
        po, line = @gen.split_sap_po_line_number(@cil.po_number)
        inv_row = ["1", po, line, @tariff_line.duty_amount + @tariff_line2.duty_amount, @cil.quantity, "ZDTY", nil]
        expect(sheet.row(1)[12, 7]).to eq(inv_row)

        # Verify the broker invoice information
        # First line is GST
        brok_inv_rows = [
          ["1", "14311000", @entry.total_gst, "S", "1017", "GST", "19999999"],
          ["2", "52111200", @broker_invoice_line1.charge_amount, "S", "1017", @broker_invoice_line1.charge_description, @profit_center.value],
          ["3", "52111200", @broker_invoice_line2.charge_amount, "S", "1017", @broker_invoice_line2.charge_description, @profit_center.value],
          ["4", "52111200", @broker_invoice_line3.charge_amount.abs, "H", "1017", @broker_invoice_line3.charge_description, @profit_center.value]
        ]
        expect(sheet.row(1)[19, 7]).to eq(brok_inv_rows[0])

        # Rest of the lines are the actual broker charges
        expect(sheet.row(2)[19, 7]).to eq(brok_inv_rows[1])
        expect(sheet.row(3)[19, 7]).to eq(brok_inv_rows[2])
        expect(sheet.row(4)[19, 7]).to eq(brok_inv_rows[3])

        # Now we need to verify the XML document structure
        expect(@xml_files.size).to eq(1)
        expect(@xml_files[0][:name]).to eq("Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")}.xml")
        d = REXML::Document.new @xml_files[0][:contents]
        expect(d.root.name).to eq "Invoices"
        expect(xp_m(d, '/Invoices/Invoice').size).to eq(1)
        expect(xp_m(d, '/Invoices/Invoice/HeaderData').size).to eq(1)
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

        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq(1)
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/InvoiceDocumentNumber')).to eq inv_row[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq po
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq line
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq inv_row[3].to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Currency')).to eq header[5]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq inv_row[4].to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/ConditionType')).to eq inv_row[5]

        expect(xp_m(d, '/Invoices/Invoice/GLAccounts/GLAccountData').size).to eq(brok_inv_rows.length)
        brok_inv_rows.each_with_index do |row, x|
          expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[#{x + 1}]/DocumentItemInInvoiceDocument")).to eq (x+1).to_s
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
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE)
      end

      it "should create an MM invoice, skip GST line if GST amount is 0, and skip duty charge lines in commercial invoices" do
        # Make this entry for an SAP PO
        @entry.update_attributes(:total_gst => BigDecimal.new(0))
        @broker_invoice_line1.update_attributes(:charge_type => "D")


        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        job = ExportJob.all.first
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail).not_to be_nil

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/GLAccounts/GLAccountData').size).to eq(2)
        expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[1]/Amount")).to eq @broker_invoice_line2.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[2]/Amount")).to eq @broker_invoice_line3.charge_amount.abs.to_s
      end

      it "should use different GL account for Brokerage fees" do
        @broker_invoice_line1.update_attributes(:charge_code => "22")

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, "/Invoices/Invoice/GLAccounts/GLAccountData[2]/GLVendorCustomer")).to eq "52111300"
      end

      it "should use tradecard invoice line quantity for Sets and combine like invoice lines" do
        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        expect(gen).to receive(:api_client).and_return api_client

        product_json = {'product' => {'classifications' => [{"class_cntry_iso" => "CA", "*cf_131" => "CS"}]}}

        expect(api_client).to receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_return product_json

        inv_line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>@cil.po_number, :quantity=> BigDecimal.new("20"))
        inv_line_2_tariff = inv_line_2.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))
        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files.size).to eq(1)

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq(1)
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
        expect(@xml_files.size).to eq(1)

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq(1)
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount + inv_line_2_tariff.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @tradecard_line.quantity.to_s
      end

      it "should use entry quantity and combine lines for non-prepack / non-set lines" do
        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        expect(gen).to receive(:api_client).and_return api_client

        product_json = {'product' => {'classifications' => [{"class_cntry_iso" => "CA", "*cf_131" => ""}]}}

        expect(api_client).to receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_return product_json

        inv_line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>@cil.po_number, :quantity=> BigDecimal.new("20"))
        inv_line_2_tariff = inv_line_2.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("4.00"))

        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files.size).to eq(1)

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq(1)
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount + inv_line_2_tariff.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq (@cil.quantity + inv_line_2.quantity).to_s
      end

      it "should use entry quantity and email RL with non-conformant line report for missing products" do
        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        expect(gen).to receive(:api_client).and_return api_client

        # API 404's on missing product
        expect(api_client).to receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_raise OpenChain::Api::ApiClient::ApiError.new(404, {'errors'=>['Not Found']})
        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files.size).to eq(1)

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq(1)
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @cil.quantity.to_s

        job = ExportJob.all.first
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail).not_to be_nil
        expect(mail.to).to eq(["rl_canada@rl.com"])
        expect(mail.subject).to eq("[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}")
        expect(mail.body.raw_source).to include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")} Exceptions.xls"]
        expect(at).not_to be_nil

        sheet = get_workbook_sheet at
        expect(sheet.name).to eq("MMGL Exceptions")
        expect(sheet.row(0)).to eq(["Entry #", "Commercial Invoice #", "PO #", "SAP Line #", "Error"])
        expect(sheet.row(1)).to eq([@entry.entry_number, @commercial_invoice.invoice_number, @cil.po_number.split("-")[0], (@cil.po_number.split("-")[1] + "0"), "No VFI Track product found for style #{@cil.part_number}."])
      end

      it "should use entry quantity and email Joanne Pauta with non-conformant line report for missing Tradecard lines" do
        @tradecard_line.destroy

        gen = OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.new
        api_client = double("ApiClient")
        expect(gen).to receive(:api_client).and_return api_client
        product_json = {'product' => {'classifications' => [{"class_cntry_iso" => "CA", "*cf_131" => "CS"}]}}

        # API 404's on missing product
        expect(api_client).to receive(:find_by_uid).with(@cil.part_number, ['class_cntry_iso', '*cf_131']).and_return product_json
        stub_xml_files gen

        gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files.size).to eq(1)

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq(1)
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number.split("-")[0]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq (@cil.po_number.split("-")[1] + '0')
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/AmountDocumentCurrency')).to eq (@tariff_line.duty_amount + @tariff_line2.duty_amount).to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @cil.quantity.to_s

        job = ExportJob.all.first
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE)

        mail = ActionMailer::Base.deliveries.pop
        expect(mail).not_to be_nil
        expect(mail.to).to eq(["rl_canada@rl.com"])
        expect(mail.subject).to eq("[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}")
        expect(mail.body.raw_source).to include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")} Exceptions.xls"]
        expect(at).not_to be_nil

        sheet = get_workbook_sheet at
        expect(sheet.name).to eq("MMGL Exceptions")
        expect(sheet.row(0)).to eq(["Entry #", "Commercial Invoice #", "PO #", "SAP Line #", "Error"])
        expect(sheet.row(1)).to eq([@entry.entry_number, @commercial_invoice.invoice_number, @cil.po_number.split("-")[0], (@cil.po_number.split("-")[1] + "0"), "No Tradecard Invoice line found for PO # #{ @cil.po_number.split("-")[0]} / SAP Line #{(@cil.po_number.split("-")[1] + "0")}"])
      end

      it "falls back to PO to find SAP Line number" do
        @tradecard_invoice.destroy
        @cil.update_attributes! po_number: "ABCD"
        make_sap_po

        order_line = Factory(:order_line, line_number: "0020", product: Factory(:product, unique_identifier: "#{@importer.fenix_customer_number}-#{@cil.part_number}"),
          order: Factory(:order, order_number: "#{@importer.fenix_customer_number}-#{@cil.po_number}")
        )

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq order_line.line_number.to_s
      end

      it "falls back to PO to find SAP Line number and uses tradecard line" do
        # Since we need the SAP line number to find the tradecard line, this ensures we're finding the SAP line prior to looking up the tradecard invoice line.
        @cil.update_attributes! po_number: "471234"
        make_sap_po

        @tradecard_line.update_attributes! unit_of_measure: "AS", quantity: "10"

        order_line = Factory(:order_line, line_number: "0010", product: Factory(:product, unique_identifier: "#{@importer.fenix_customer_number}-#{@cil.part_number}"),
          order: Factory(:order, order_number: "#{@importer.fenix_customer_number}-#{@cil.po_number}")
        )

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchaseOrderNumber')).to eq @cil.po_number
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/PurchasingDocumentItemNumber')).to eq order_line.line_number.to_s
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq @cil.quantity.to_s
      end

      it "skips commercial invoice lines with no duty" do
        # Keep the part number / etc the same, that way we don't have to make any expectation adjustments
        cil2 =  Factory(:commercial_invoice_line, :commercial_invoice => @commercial_invoice, :part_number => 'ABCDEFG', :po_number=>"1234-1", :quantity=> BigDecimal.new("100"))
        tariff_line = cil2.commercial_invoice_tariffs.create!(:duty_amount => BigDecimal.new("0"))

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_m(d, '/Invoices/Invoice/Items/ItemData').size).to eq 1
        expect(xp_t(d, '/Invoices/Invoice/Items/ItemData/Quantity')).to eq "10.0"
      end

      context "multiple invoices same entry mm/gl split" do
        it "should know if an entry has been sent already during the same generation and send FFI format for second" do
          # create a second broker invoice for the same entry, and make sure it's output in FFI format
          # this also tests making multiple export jobs and attaching multiple files to the email

          @broker_invoice2 = Factory(:broker_invoice, :entry => @entry, :invoice_date => Date.new(2013,06,02), :invoice_number => 'INV2')
          @broker_invoice2_line1 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("5.00"))

          @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice, @broker_invoice2]

          job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE).first
          expect(job).not_to be_nil

          job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE).first
          expect(job).not_to be_nil

          expect(@xml_files.size).to eq(2)
          expect(@xml_files[0][:name]).to eq "Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")}.xml"
          expect(@xml_files[1][:name]).to eq "Vandegrift FI RL #{job.start_time.strftime("%Y%m%d")}.xml"

          d = REXML::Document.new @xml_files[0][:contents]
          expect(xp_t(d, "/Invoices/Invoice/HeaderData/Reference")).to eq @broker_invoice.invoice_number

          # Invoice # isn't in the FFI file, so just use what's there and the document structure confirms
          # it's actually an FFI file
          d = REXML::Document.new @xml_files[1][:contents]
          expect(xp_t(d, "/Invoices/Invoice/HeaderData/REFERENCE")).to eq @broker_invoice2.invoice_number
        end
      end

      it "should generate and email an MM excel file for Club Monaco" do
        club_monaco = Factory(:importer, fenix_customer_number: "866806458RM0001")
        @entry.update_attributes! importer: club_monaco
        time = Time.zone.now
        profit_center = DataCrossReference.create!(:cross_reference_type=>'profit_center', :key=>'ABC', :value=>'Profit', company_id: club_monaco.id)

        @gen.generate_and_send_invoices :club_monaco, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        mail = ActionMailer::Base.deliveries.pop
        expect(mail).to_not be_nil
        expect(mail.to).to eq(["club_monaco@rl.com"])
        expect(mail.subject).to eq("[VFI Track] Vandegrift, Inc. Club Monaco Invoices for #{job.start_time.strftime("%m/%d/%Y")}")
        expect(mail.body.raw_source).to include "An MM and/or FFI invoice file is attached for Club Monaco for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        at = mail.attachments["Vandegrift MM CM #{job.start_time.strftime("%Y%m%d")}.xls"]
        expect(at).not_to be_nil

        sheet = get_workbook_sheet at
        expect(sheet.name).to eq("MMGL")
        # We only need to validate the file differences between CM and RL CA
        # Which is the company code and unallocated profit center differences

        expect(sheet.row(1)[3]).to eq "1710"
        expect(sheet.row(1)[23]).to eq "1710"
        # First line is always GST, which is always the unallocated profit center
        expect(sheet.row(1)[25]).to eq "20399999"
        expect(sheet.row(2)[25]).to eq @profit_center.value
      end
    end

    context "FFI_Invoices" do

      before :each do
        # Make line 2 a brokerage fee
        @broker_invoice_line2.update_attributes! charge_code: "22"
      end

      it "should generate an FFI invoice for non-deployed brands" do
        # By virtue of not setting up the entry/invoice line PO# as an SAP PO and not setting up a brand x-ref
        # we'll get an FFI format output
        # This also means we'll be using the 199.. profit center for everything

        # Make the first charge an HST charge (verify the correct g/l account is used for that)
        @broker_invoice_line1.update_attributes!(:charge_code=>"250", :charge_description=>"123456789012345678901234567890123456789012345678901")
        time = Time.zone.now

        @gen.generate_and_send_invoices :rl_canada, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        expect(job).not_to be_nil
        expect(job.start_time.to_i).to eq(time.to_i)
        # Shouldn't be more than 5 seconds from export job "end time"
        expect(Time.zone.now.to_i - job.end_time.to_i).to be <= 5
        expect(job.successful).to be_truthy
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)
        expect(job.attachments.length).to eq(2)
        expect(job.attachments.first.attached_file_name).to eq("Vandegrift FI RL #{job.start_time.strftime("%Y%m%d")}.xls")
        expect(job.attachments.second.attached_file_name).to eq("Vandegrift FI RL #{job.start_time.strftime("%Y%m%d")}.xml")

        mail = ActionMailer::Base.deliveries.pop
        expect(mail).not_to be_nil
        expect(mail.subject).to eq("[VFI Track] Vandegrift, Inc. RL Canada Invoices for #{job.start_time.strftime("%m/%d/%Y")}")
        expect(mail.body.raw_source).to include "An MM and/or FFI invoice file is attached for RL Canada for 1 invoice as of #{job.start_time.strftime("%m/%d/%Y")}."

        expect(mail.attachments.size).to eq(1)

        expect(mail.attachments["Vandegrift FI RL #{job.start_time.strftime("%Y%m%d")}.xls"]).not_to be_nil

        sheet = get_workbook_sheet mail.attachments["Vandegrift FI RL #{job.start_time.strftime("%Y%m%d")}.xls"]
        expect(sheet.name).to eq("FFI")
        now = job.start_time.strftime("%m/%d/%Y")
        rows = []
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "31", "100023825", nil, BigDecimal.new("18.99"), "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "49999999", nil, @entry.entry_number, nil]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "23109000", nil, @entry.total_duty, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, "Duty"]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "14311000", nil, @entry.total_gst, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, "GST"]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "14311000", nil, @broker_invoice_line1.charge_amount, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, @broker_invoice_line1.charge_description[0, 50]]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "52111300", nil, @broker_invoice_line2.charge_amount, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, @broker_invoice_line2.charge_description[0, 50]]
        rows << [@broker_invoice.invoice_date.strftime("%m/%d/%Y"), 'KR', '1017',now, 'CAD', nil, nil, nil, @broker_invoice.invoice_number, "40", "23101900", nil, @broker_invoice_line3.charge_amount, "0001", now, nil, nil, nil, nil, nil, nil, nil, nil, nil, "19999999", nil, @entry.entry_number, @broker_invoice_line3.charge_description[0, 50]]

        expect(sheet.row(1)).to eq(rows[0])
        expect(sheet.row(2)).to eq(rows[1])
        expect(sheet.row(3)).to eq(rows[2])
        expect(sheet.row(4)).to eq(rows[3])
        expect(sheet.row(5)).to eq(rows[4])
        expect(sheet.row(6)).to eq(rows[5])

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        h = rows[0]
        expect(xp_m(d, '/Invoices/Invoice/HeaderData').size).to eq(1)
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/COMPANYCODE')).to eq h[2]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DOCUMENTTYPE')).to eq h[1]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/DOCUMENTDATE')).to eq @broker_invoice.invoice_date.strftime("%Y%m%d")
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/POSTINGDATE')).to eq job.start_time.strftime("%Y%m%d")
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/REFERENCE')).to eq h[8]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq h[10]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq h[12].to_s
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/CURRENCYCODE')).to eq h[4]
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/BASELINEDATE')).to eq job.start_time.strftime("%Y%m%d")


        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData').size).to eq(5)

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
        expect(job).not_to be_nil
        mail = ActionMailer::Base.deliveries.pop

        sheet = get_workbook_sheet mail.attachments["Vandegrift FI CM #{job.start_time.strftime("%Y%m%d")}.xls"]
        # The only differences here should be the company code and the profit centers utilized
        expect(sheet.row(1)[2]).to eq "1710"
        expect(sheet.row(2)[24]).to eq "20399999"
      end

      it "should use unallocated profit center for CM invoices on HST/GST Lines" do
        @broker_invoice_line1.update_attributes! charge_code: "250"
        allow(@gen).to receive(:find_profit_center).and_return "profit_center"

        # All that we need to check here is the differences between rl ca and club monaco
        time = Time.zone.now
        @gen.generate_and_send_invoices :club_monaco, time, [@broker_invoice]

        # A single ExportJob should have been created
        job = ExportJob.all.first
        expect(job).not_to be_nil
        mail = ActionMailer::Base.deliveries.pop

        sheet = get_workbook_sheet mail.attachments["Vandegrift FI CM #{job.start_time.strftime("%Y%m%d")}.xls"]
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
        expect(job).not_to be_nil
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)
        now = job.start_time.strftime("%m/%d/%Y")

        # Verify the profit center is the 199.. one (aside from the FFI invoice instead of MM, that's the only thing to look out for here)
        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/PROFITCENTER")).to eq "19999999"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[4]/PROFITCENTER")).to eq "19999999"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[5]/PROFITCENTER")).to eq "19999999"

        # This should also result in the charge for the 3rd line being allotted to the non-deployed brand GL Account (since there's no profit center to assign it to)
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[5]/GLVENDORCUSTOMER")).to eq "23101900"
      end

      it "should generate an FFI invoice for SAP PO's that have already had an invoice sent" do
        make_sap_po

        allow(@gen).to receive(:previously_invoiced?).with(@entry).and_return true

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        job = ExportJob.all.first
        expect(job).not_to be_nil
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)

        mail = ActionMailer::Base.deliveries.pop
        sheet = get_workbook_sheet mail.attachments.first
        now = job.start_time.strftime("%m/%d/%Y")

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        # Because we've sent an invoice for the entry already, we don't include duty or GST in the total or in the charge lines
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq "100023825"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq BigDecimal.new("8.00").to_s

        # Since this is an SAP PO, we should be using the actual SAP profit center from the xref (and use the gl account indicating
        # a deployed brand)
        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData').size).to eq(3)
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/AMOUNT")).to eq @broker_invoice_line1.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/AMOUNT")).to eq @broker_invoice_line2.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/AMOUNT")).to eq @broker_invoice_line3.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/GLVENDORCUSTOMER")).to eq "52111200"
      end

      it "should skip GST/Duty lines for entries previously invoiced using the FFI interface" do
        # Just like we skip the gst/duty lines for SAP entries we've already sent via MM, we need to do the
        # same when we've sent the entry previously via FFI interface

        allow(@gen).to receive(:previously_invoiced?).with(@entry).and_return true

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]
        job = ExportJob.all.first
        expect(job).not_to be_nil
        expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)

        expect(@xml_files.size).to eq(1)
        d = REXML::Document.new @xml_files[0][:contents]
        # Because we've sent an invoice for the entry already, we don't include duty or GST in the total or in the charge lines
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/INVOICINGPARTY')).to eq "100023825"
        expect(xp_t(d, '/Invoices/Invoice/HeaderData/AMOUNT')).to eq BigDecimal.new("8.00").to_s

        # Since this is an SAP PO, we should be using the actual SAP profit center from the xref
        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData').size).to eq(3)
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/AMOUNT")).to eq @broker_invoice_line1.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/AMOUNT")).to eq @broker_invoice_line2.charge_amount.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/AMOUNT")).to eq @broker_invoice_line3.charge_amount.to_s
      end

      it "should generate a credit FFI invoice" do
        # Skip the duty/gst lines so only the invoice lines are accounted for, this is how it'll end up being invoiced
        # for real anyway.
        allow(@gen).to receive(:previously_invoiced?).with(@entry).and_return true
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
        expect(xp_m(d, '/Invoices/Invoice/GLAccountDatas/GLAccountData').size).to eq(3)
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/CreditDebitIndicator")).to eq "H"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[1]/AMOUNT")).to eq @broker_invoice_line1.charge_amount.abs.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/CreditDebitIndicator")).to eq "H"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[2]/AMOUNT")).to eq @broker_invoice_line2.charge_amount.abs.to_s
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/CreditDebitIndicator")).to eq "H"
        expect(xp_t(d, "/Invoices/Invoice/GLAccountDatas/GLAccountData[3]/AMOUNT")).to eq @broker_invoice_line3.charge_amount.abs.to_s
      end

      it "generates FF invoices for Polo Factory stores" do
        @broker_invoice_line3.destroy
        @broker_invoice_line1.update_attributes! charge_code: "22"
        @broker_invoice_line2.update_attributes! charge_code: "250"

        @gen.generate_and_send_invoices :factory_stores, Time.zone.now, [@broker_invoice]

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ["factory_stores@rl.com"]
        sheet = get_workbook_sheet mail.attachments.first
        # Just check the columns that should be different than the other documents
        # .ie most of the account codes
        expect(sheet.row(1)[2]).to eq "1540"
        expect(sheet.row(1)[10]).to eq "100023825"
        expect(sheet.row(1)[12]).to eq 9.0
        expect(sheet.row(1)[24]).to be_nil
        expect(sheet.row(1)[25]).to be_nil

        expect(sheet.row(2)[2]).to eq "1540"
        expect(sheet.row(2)[10]).to eq "50960180"
        expect(sheet.row(2)[12]).to eq 5.0
        expect(sheet.row(2)[24]).to eq "20299699"
        expect(sheet.row(2)[25]).to eq "1115"

        expect(sheet.row(3)[2]).to eq "1540"
        expect(sheet.row(3)[10]).to eq "14311000"
        expect(sheet.row(3)[12]).to eq 4.0
        expect(sheet.row(3)[24]).to eq "20299699"
        expect(sheet.row(3)[25]).to eq "1115"
      end

      context "ff send exceptions" do
        before :each do
          # Test with SAP invoices, since these would normally go as MM files...we can show that we're overriding the normal
          # behavior for stock transfers
          make_sap_po
        end

        it "generates FF invoices for RL Canada stock transfers" do
          # Test with SAP invoices, since these would normally go as MM files...we can show that we're overriding the normal
          # behavior for stock transfers
          make_sap_po
          @entry.update_attributes! vendor_names: "Ralph Lauren Corp"

          @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

          # A single ExportJob should have been created
          job = ExportJob.all.first
          expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)
        end

        it "generates FF invoices when every line is duty free" do
          # Test with SAP invoices, since these would normally go as MM files...we can show that we're overriding the normal
          # behavior for stock transfers
          make_sap_po
          [@tariff_line, @tariff_line2].each {|l| l.update_column :duty_amount, 0}

          @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

          job = ExportJob.all.first
          expect(job.export_type).to eq(ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)
        end
      end

    end

    context "multiple_invoices_same_entry" do
      it "should know if an entry has been sent already during the same generation and send FFI format for second" do
        # create a second broker invoice for the same entry, and make sure it's output in FFI format
        # this also tests making multiple export jobs and attaching multiple files to the email
        make_sap_po

        @broker_invoice2 = Factory(:broker_invoice, :entry => @entry, :invoice_date => Date.new(2013,06,01), :invoice_number => 'INV2')
        @broker_invoice2_line1 = Factory(:broker_invoice_line, :broker_invoice => @broker_invoice, :charge_amount => BigDecimal("5.00"))

        @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice, @broker_invoice2]

        job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE).first
        expect(job).not_to be_nil

        job = ExportJob.where(:export_type => ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE).first
        expect(job).not_to be_nil

        expect(@xml_files.size).to eq(2)
        expect(@xml_files[0][:name]).to eq "Vandegrift MM RL #{job.start_time.strftime("%Y%m%d")}.xml"
        expect(@xml_files[1][:name]).to eq "Vandegrift FI RL #{job.start_time.strftime("%Y%m%d")}.xml"

        d = REXML::Document.new @xml_files[0][:contents]
        expect(xp_t(d, "/Invoices/Invoice/HeaderData/Reference")).to eq @broker_invoice.invoice_number

        # Invoice # isn't in the FFI file, so just use what's there and the document structure confirms
        # it's actually an FFI file
        d = REXML::Document.new @xml_files[1][:contents]
        expect(xp_t(d, "/Invoices/Invoice/HeaderData/REFERENCE")).to eq @broker_invoice2.invoice_number
      end
    end
  end

  context "previously_invoiced?" do
    it "should identify an entry as not having been invoiced" do
      expect(@gen.previously_invoiced?(@entry)).to be_falsey
    end

    it "should not identify an entry as having been invoiced if the export job is not successful" do
      j = ExportJob.new
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      expect(@gen.previously_invoiced?(@entry)).to be_falsey
    end

    it "should identify an entry as being invoiced if it has a successful export job associated with it" do
      j = ExportJob.new
      j.successful = true
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      expect(@gen.previously_invoiced?(@entry)).to be_truthy
    end
  end

  context "find_broker_invoices" do
    it "should find broker invoices for RL Canada after June 1, 2013 that have not been succssfully invoiced" do
      # the default invoice should be found
      invoices = @gen.find_broker_invoices :rl_canada
      expect(invoices.first.id).to eq @broker_invoice.id
    end

    it "should find broker invoices for Club Monaco after May 23, 2014 that have not been succssfully invoiced" do
      @broker_invoice.update_attributes! invoice_date: '2014-05-24'
      club_monaco = Factory(:importer, fenix_customer_number: "866806458RM0001")
      @broker_invoice.entry.update_attributes! importer: club_monaco

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

      expect(@gen.find_broker_invoices(:rl_canada).size).to eq(0)
    end

    it "should not find RL Canada invoices prior to June 1, 2013" do
      @broker_invoice.update_attributes(:invoice_date => Date.new(2013, 5, 31))
      expect(@gen.find_broker_invoices(:rl_canada).size).to eq(0)
    end

    it "should not find Club Monaco invoices prior to May 23, 2014" do
      club_monaco = Factory(:importer, fenix_customer_number: "866806458RM0001")
      @broker_invoice.entry.update_attributes! importer: club_monaco

      @broker_invoice.update_attributes(:invoice_date => Date.new(2014, 5, 22))
      expect(@gen.find_broker_invoices(:club_monaco).size).to eq(0)
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
      expect(@gen.find_broker_invoices(:rl_canada).size).to eq(0)
    end

    it "does not include invoices that failed and then were successfully sent later" do
      # regression test for a bug that sent invoices when it shouldn't have.
      j = ExportJob.new
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.successful = false
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      j = ExportJob.new
      j.export_type = ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE
      j.successful = true
      j.export_job_links.build.exportable = @broker_invoice

      j.save!

      expect(@gen.find_broker_invoices(:rl_canada).size).to eq(0)
    end
  end

  context "find_generate_and_send_invoices" do
    it "should run in eastern timezone, call find invoices, and generate" do
      # everything done in the generation and find invoices is already tested..so just make sure this method just
      # calls the right things (yes, I'm pretty much just mocking every call.)
      zone = double("zone")
      now = double("now")

      allow(Time).to receive(:use_zone).with("Eastern Time (US & Canada)").and_yield
      allow(Time).to receive(:zone).and_return zone
      allow(zone).to receive(:now).and_return now
      expect(@gen).to receive(:find_broker_invoices).with(:rl_canada).and_return([@broker_invoice])
      expect(@gen).to receive(:find_broker_invoices).with(:club_monaco).and_return([])
      expect(@gen).to receive(:find_broker_invoices).with(:factory_stores).and_return([])
      expect(@gen).to receive(:generate_and_send_invoices).with(:rl_canada, now, [@broker_invoice])
      expect(@gen).to receive(:generate_and_send_invoices).with(:club_monaco, now, [])
      expect(@gen).to receive(:generate_and_send_invoices).with(:factory_stores, now, [])

      @gen.find_generate_and_send_invoices
    end
  end

  context "run_schedulable" do
    it "should instantiate a new generator and run the process" do
      # The only thing this method does is instantiate a new generator and call a method..just make sure it's doing that
      expect_any_instance_of(OpenChain::CustomHandler::PoloSapInvoiceFileGenerator).to receive(:find_generate_and_send_invoices)
      OpenChain::CustomHandler::PoloSapInvoiceFileGenerator.run_schedulable {}
    end
  end

  context "exception_handling" do
    it "should log an exception containing a spreadsheet with all errors encountered while building the invoice files" do
      # hook into a method in generate_invoice_output and have it raise an error so we can test error handling
      # during the invoice file generation
      expect(@gen).to receive(:determine_invoice_output_format).and_raise "Error to log."
      sheet = nil
      expect(OpenMailer).to receive(:send_generic_exception) do |ex,messages,message,trace,file_paths|
        expect(messages[0]).to eq("See attached spreadsheet for full list of invoice numbers that could not be generated.")
        sheet = Spreadsheet.open(file_paths[0]).worksheet 0
        obj = double('mailer')
        expect(obj).to receive(:deliver)
        obj
      end

      expect(@gen).to receive(:production?).and_return true
      @gen.generate_and_send_invoices :rl_canada, Time.zone.now, [@broker_invoice]

      expect(sheet.row(1)[0]).to eq(@broker_invoice.invoice_number)
      expect(sheet.row(1)[1]).to eq("Error to log.")
      # This is the backtrace, so just make sure this looks somewhat like a backtrace should
      expect(sheet.row(1)[2]).to match(/lib\/open_chain\/custom_handler\/polo_sap_invoice_file_generator\.rb:\d+/)
    end
  end

  describe "ftp_credentials" do
    it "uses ftp2" do
      expect(@gen.ftp_credentials).to eq server: "ftp2.vandegriftinc.com", username: "VFITRACK", password: "RL2VFftp", folder: "to_ecs/Ralph_Lauren/sap_invoices", protocol: "sftp"
    end
  end
end
