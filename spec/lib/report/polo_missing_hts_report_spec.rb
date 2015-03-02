require 'spec_helper'

describe OpenChain::Report::PoloMissingHtsReport do

  def get_emailed_worksheet sheet_name, file_name, mail = ActionMailer::Base.deliveries.pop
    fail("Expected at least one mail message.") unless mail
    at = mail.attachments[file_name]
    expect(at).not_to be_nil
    wb = Spreadsheet.open(StringIO.new(at.read))
    wb.worksheets.find {|s| s.name == sheet_name}
  end

  describe "run" do
    before :each do
     @cdefs = Class.new {include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport}.prep_custom_definitions [:prod_part_number, :ord_line_ex_factory_date, :ord_division]

     @ca = Factory(:country, iso_code: "CA")
     line = Factory(:order_line, order: Factory(:order, customer_order_number: "ORDER"))
     @order = line.order
     @product = line.product
     @order.update_attributes! importer: Factory(:importer, fenix_customer_number: "806167003RM0001")
     @order.update_custom_value! @cdefs[:ord_division], "DIVISION"
     @product.update_custom_value! @cdefs[:prod_part_number], "STYLE"
     line.update_custom_value! @cdefs[:ord_line_ex_factory_date], Date.new(2015, 2, 1)
    end

    it "identifies styles shipping inside the specified date period without hts records and emails them to recipients" do
      described_class.new.run Date.new(2015,2,1), Date.new(2015,2,2), ["me@there.com"]

      sheet = get_emailed_worksheet 'Missing CA HTS Report', "Missing CA HTS Report 2015-02-01 - 2015-02-02.xls"

      expect(sheet).not_to be_nil
      expect(sheet.row(0)).to eq ["Order Number", "Style", "Ex-Factory Date", "Merchandise Division"]
      expect(sheet.row(1)).to eq ["ORDER", "STYLE", excel_date(Date.new(2015, 2, 1)), "DIVISION"]
    end

    it "finds products from both RL importers" do
      @order.update_attributes! importer: Factory(:importer, fenix_customer_number: "866806458RM0001")
      described_class.new.run Date.new(2015,2,1), Date.new(2015,2,2), ["me@there.com"]

      sheet = get_emailed_worksheet 'Missing CA HTS Report', "Missing CA HTS Report 2015-02-01 - 2015-02-02.xls"
      expect(sheet.row(1)).to eq ["ORDER", "STYLE", excel_date(Date.new(2015, 2, 1)), "DIVISION"]
    end

    it "does not list products shipping before daterange" do
      described_class.new.run Date.new(2015,2,2), Date.new(2015,2,3), ["me@there.com"]

      sheet = get_emailed_worksheet 'Missing CA HTS Report', "Missing CA HTS Report 2015-02-02 - 2015-02-03.xls"

      expect(sheet).not_to be_nil
      expect(sheet.row(1)).to eq ["No Styles missing CA HTS values."]
    end

    it "does not list products shipping after daterange" do
      described_class.new.run Date.new(2015,1,30), Date.new(2015,1,31), ["me@there.com"]

      sheet = get_emailed_worksheet 'Missing CA HTS Report', "Missing CA HTS Report 2015-01-30 - 2015-01-31.xls"

      expect(sheet).not_to be_nil
      expect(sheet.row(1)).to eq ["No Styles missing CA HTS values."]
    end

    it "does not list products with valid CA HTS numbers" do
      matching_product = Factory(:product, unique_identifier: "RLMASTER-STYLE")
      ot = OfficialTariff.create! hts_code: '1234567890', country: @ca
      t = Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, country: @ca, product: matching_product))

      rpt = described_class.new
      rpt.run Date.new(2015,2,1), Date.new(2015,2,2), ["me@there.com"]

      sheet = get_emailed_worksheet 'Missing CA HTS Report', "Missing CA HTS Report 2015-02-01 - 2015-02-02.xls"

      expect(sheet).not_to be_nil
      expect(sheet.row(1)).to eq ["No Styles missing CA HTS values."]
    end


  end
end

