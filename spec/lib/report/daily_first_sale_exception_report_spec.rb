require 'spec_helper'

describe OpenChain::Report::DailyFirstSaleExceptionReport do
  let(:report) { described_class.new }
  #                  0           1                 2                 3              4              5          6      7       8         9        10       11       12        13      14      15             16            17              18            19              20         21            22          23           24      25         26                 27                       28
  let(:header) { ['Entry#','Release Date', 'Entry Filed Date', 'Duty Due Date','Master Bills','House Bills','PO#','Brand','Item#', 'Invoice#','COO','Department','HTS','Duty Rate','MID','Supplier', 'Vendor Name', 'Vendor Number', 'AGS Office', 'Item Quantity','Item UOM', 'Value', 'Invoice Value','Entered Value','Duty','NDC', 'Price to Brand', 'Vendor Price to AGS', 'First Sale Price'] }
  let(:cdefs) { described_class.prep_custom_definitions [:ord_selling_agent, :ord_type] }                  
  
  def create_data
    Factory(:company, alliance_customer_number: "ASCE", importer:true)
    
    @today = ActiveSupport::TimeZone["UTC"].now.beginning_of_day
    @yesterday = @today - 1.day
    @day_before_yesterday = @yesterday - 1.day
    @tomorrow = @today + 1.day
    DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid")
    vend = Factory(:company, name: "vend name", system_code: "vend sys code")
    @ent = Factory(:entry, import_country: Factory(:country, iso_code: 'US'), customer_number: 'ASCE', entry_filed_date: @day_before_yesterday,
                    first_entry_sent_date: @today, entry_number: 'entry num', release_date: @yesterday, 
                    duty_due_date: @tomorrow, master_bills_of_lading: 'mbols', house_bills_of_lading: 'hbols')
    @ci = Factory(:commercial_invoice, entry: @ent, invoice_number: 'inv num', invoice_value: 2)
    @cil = Factory(:commercial_invoice_line, commercial_invoice: @ci, contract_amount: 0, po_number: 'po num', part_number: 'part num', 
                    country_origin_code: 'coo', department: 'dept', vendor_name: 'supplier', quantity: 6, unit_of_measure: 'uom', 
                    value: 1, non_dutiable_amount: 5, mid: 'mid', product_line: 'brand', unit_price: 3)
    @cit = Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil, hts_code: 'hts', entered_value: 1, duty_rate: 7, duty_amount: 8)

    @prod = Factory(:product, unique_identifier: 'ASCENA-part num')
    @ord = Factory(:order, order_number: 'ASCENA-po num', vendor: vend)
    @ord.find_and_set_custom_value(cdefs[:ord_type], 'AGS')
    @ord.find_and_set_custom_value(cdefs[:ord_selling_agent], 'agent')
    @ord.save!
    @ordln = Factory(:order_line, order: @ord, product: @prod, price_per_unit: 1)
  end

  describe "permission?" do
    before do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end
    
    let!(:linked) { Factory(:company, alliance_customer_number: "ASCE", importer: true) }
    let!(:co) { Factory(:company, linked_companies: [linked]) }

    it "allows user at master company who can view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "allows Ascena user who can view entries" do
      u = Factory(:user, company: co)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "blocks user who can't view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return false
      expect(described_class.permission? u).to eq false
    end

    it "blocks user who doesn't belong to Ascena or master company" do
      u = Factory(:user)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq false
    end
  end

  describe "get_mids" do
    it "retrieves mids" do
      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid1")
      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid2")

      expect(described_class.get_mids).to eq ["mid1", "mid2"]
    end

    it "returns empty string if list is empty" do
      expect(described_class.get_mids).to eq []
    end
  end

  describe "run_report" do
    after { @temp.close if @temp }

    it "generates spreadsheet with datetimes in user's time zone" do
      create_data
      u = Factory(:user, time_zone: "Eastern Time (US & Canada)")

      @temp = described_class.run_report u
      wb = Spreadsheet.open @temp.path
      sheet = wb.worksheets[0]

      expect(sheet.name).to eq "Daily First Sale Exception Report"
      expect(sheet.rows.count).to eq 2
      expect(sheet.row(0)).to eq header
      expect(sheet.row(1)[1]).to eq @yesterday.in_time_zone(u.time_zone).strftime("%Y-%m-%d %H:%M")
    end
  end

  describe "run_schedulable" do
    it "sends email with attachment (datetimes in Eastern time)" do
      create_data
      described_class.run_schedulable({'email' => ['test@vandegriftinc.com']})
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "test@vandegriftinc.com" ]
      expect(mail.subject).to eq "Daily First Sale Exception Report"
      expect(mail.attachments.count).to eq 1

      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        wb = Spreadsheet.open t.path
        sheet = wb.worksheet(0)
        
        expect(sheet.count).to eq 2
        expect(sheet.row(0)).to eq header
        expect(sheet.row(1)[1]).to eq @yesterday.in_time_zone("Eastern Time (US & Canada)").strftime("%Y-%m-%d %H:%M")
      end
    end
  end

  describe 'query' do
    before { create_data }

    it "produces expected results" do
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 1
      expect(db_result.fields).to eq header
      #                                   0            1                 2                           3           4        5        6       7        8          9      10     11    12     13   14       15         16               17            18     19   20    21   22  23   24   25  26  27  28
      expect(db_result.first).to eq ['entry num', @yesterday, @day_before_yesterday.to_date, @tomorrow.to_date,'mbols','hbols','po num','brand','part num','inv num','coo','dept','hts', 700, 'mid','supplier', 'vend name', 'vend sys code',  'agent',   6, 'uom',  1,   2,  1,   8,   5,  3,  1,  0]
    end

    it "omits non-US entries" do
      @ent.update_attributes(import_country: Factory(:country, iso_code: "CA"))
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "omits non-Ascena entries" do
      @ent.update_attributes(customer_number: "ACME")
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "omits entries without first_entry_sent_date" do
      @ent.update_attributes(first_entry_sent_date: nil)
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "omits entries with a past duty_due_date" do
      @ent.update_attributes(duty_due_date: @today - 1.day)
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "omits invoices with a contract_amount" do
      @cil.update_attributes(contract_amount: 100)
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "omits tariffs whose entered_value doesn't equal the invoice line's value" do
      @cit.update_attributes(entered_value: 100)
      db_result = ActiveRecord::Base.connection.execute report.query(['mid'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "omits invoice lines whose mfid isn't specified" do
      db_result = ActiveRecord::Base.connection.execute report.query(['foo'], cdefs)
      expect(db_result.count).to eq 0
    end

    it "handles a blank mfid list" do
      db_result = ActiveRecord::Base.connection.execute report.query([], cdefs)
      expect(db_result.count).to eq 0
    end
  end
end