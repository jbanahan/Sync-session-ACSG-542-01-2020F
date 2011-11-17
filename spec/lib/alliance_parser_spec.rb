require 'spec_helper'

describe OpenChain::AllianceParser do
  before :each do
    @ref_num ='0000364690' 
    @cust_num = "NJEAN"
    @extract_date_str = "201002190115"
    @company_number = '01'
    @division = '9988'
    @customer_name = 'cust name'
    @entry_type = '02'
    @arrival_date_str = "201002201444"
    @entry_filed_date_str = "201002142326"
    @release_date_str = '201104231921'
    @first_release_date_str = '201103301521'
    @free_date_str = '201004221201'
    @last_billed_date_str = '201005121822'
    @invoice_paid_date_str = '201101031442'
    @liquidation_date_str = '201104021522'
    @make_entry_lambda = lambda {
      sh00 = "SH00#{@ref_num}#{@cust_num.ljust(10)}#{@extract_date_str}#{@company_number}#{@division}#{@customer_name.ljust(35)}samples                                                               IDID000004701470140#{@entry_type}316003646907NJEAN     NAUTICA MENS JEANS DIV VF SPORTS   EY  00F792ETIHAD AIRWAYS                     ETIHAD AIRWAYS      101       000000000001CTNS  0000000000050000000014400WEDG047091068823N   N01No Change                          00change liquidation                 00                                   0LQ090419ESP       N05 YYYYVFEDI     "
      sd_arrival = "SD0000012#{@arrival_date_str}200904061628Arr POE Arrival Date Port of Entry                                  "
      sd_entry_filed = "SD0000016#{@entry_filed_date_str}2009040616333461FILDEntry Filed (3461,3311,7523)                                "
      sd_release = "SD0000019#{@release_date_str}200904061633Release Release Date                                                "
      sd_first_release = "SD0099202#{@first_release_date_str}200904061633Ist Rel First Release date                                          "
      sd_free = "SD0000052#{@free_date_str}200904081441Free    Free Date                                                   "
      sd_last_billed = "SD0000028#{@last_billed_date_str}200904061647Bill PrtLast Billed                                                 "
      sd_invoice_paid = "SD0000032#{@invoice_paid_date_str}200905111220InvPaid Invoice Paid by Customer                                    "
      sd_liquidation = "SD0000044#{@liquidation_date_str}201002190115Liq DateLiquidation Date                                            "
      [sh00,sd_arrival,sd_entry_filed,sd_release,sd_first_release,sd_free,sd_last_billed,sd_invoice_paid,sd_liquidation].join("\n")
    }
    @inv_suffix = "01"
    @inv_invoice_date_str = "20090406"
    @inv_total = BigDecimal("12.34",2)
    @inv_b_name = 'billname'
    @inv_b_add_1 = 'b address 1'
    @inv_b_add_2 = 'b address 2'
    @inv_b_city = 'bc city'
    @inv_b_state = 'NJ'
    @inv_b_zip = '12345'
    @inv_b_country_iso = 'US'
    @country = Factory(:country,:iso_code=>'US')
    @invoice_lines = [
      {:code=>'0099',:desc=>'CHARGDESC',:amt=>BigDecimal.new("10.01",2),:v_name=>'VNAME',:v_ref=>"VREF",:type=>"D"},
      {:code=>'0021',:desc=>'CHARGDESC2',:amt=>BigDecimal.new("2.33",2),:v_name=>'VN2',:v_ref=>"VREF2",:type=>"R"},
    ]
    @make_invoice_lambda = lambda {
      ih00 = "IH00#{@inv_suffix}#{@inv_invoice_date_str}#{@cust_num.ljust(10)}#{(@inv_total*100).to_i.to_s.rjust(11,'0')}000000000000000000000000000000000000000000000000#{@inv_b_name.ljust(35)}#{@inv_b_add_1.ljust(35)}#{@inv_b_add_2.ljust(35)}#{@inv_b_city.ljust(35)}#{@inv_b_state}#{@inv_b_zip.ljust(9)}#{@inv_b_country_iso}"
      i_trailer = "IT00                                                                      000000018080000000000000000000000000"
      rows = [ih00]
      @invoice_lines.each {|h| rows << "IL00#{h[:code]}#{h[:desc].ljust(35)}#{(h[:amt]*100).to_i.to_s.rjust(11,'0')}#{h[:v_name].ljust(30)}#{h[:v_ref].ljust(15)}#{h[:type]}"}
      rows << i_trailer
      rows.join("\n")
    }
    @si_lines = [
      {:mbol=>'MAEU12345678',:it=>'123456789',:hbol=>'H325468',:sub=>'S19148kf'},
      {:mbol=>'OOCL81851511',:it=>'V58242151',:hbol=>'H35156181',:sub=>'S5555555'}
    ]
    @make_si_lambda = lambda {
      rows = []
      @si_lines.each {|h| rows << "SI00#{h[:it].ljust(12)}#{h[:mbol].ljust(16)}#{h[:hbol].ljust(12)}#{h[:sub].ljust(12)}"}
      rows.join("\n")
    }
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end
  it 'should create entry' do
    file_content = @make_entry_lambda.call
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    ent.customer_number.should == @cust_num
    ent.last_exported_from_source.should == @est.parse(@extract_date_str)
    ent.company_number.should == @company_number
    ent.division_number.should == @division
    ent.customer_name.should == @customer_name
    ent.entry_type.should == @entry_type
    ent.arrival_date.should == @est.parse(@arrival_date_str)
    ent.entry_filed_date.should == @est.parse(@entry_filed_date_str)
    ent.release_date.should == @est.parse(@release_date_str)
    ent.first_release_date.should == @est.parse(@first_release_date_str)
    ent.free_date.should == @est.parse(@free_date_str)
    ent.last_billed_date.should == @est.parse(@last_billed_date_str)
    ent.invoice_paid_date.should == @est.parse(@invoice_paid_date_str)
    ent.liquidation_date.should == @est.parse(@liquidation_date_str)
  end
  it 'should create two entries' do
    r1 = '1234567890'
    r2 = '5647894565'
    fc_array = []
    [r1,r2].each do |r|
      @ref_num = r
      fc_array << @make_entry_lambda.call
    end
    file_content = fc_array.join("\n")
    OpenChain::AllianceParser.parse file_content
    Entry.count.should == 2
    [r1,r2].each {|r| Entry.find_by_broker_reference(r).should_not be_nil}
  end
  it 'should update entry' do
    file_content = @make_entry_lambda.call
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    ent.customer_number.should == @cust_num
    @cust_num = 'ABC'
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.count.should == 1
    Entry.find(ent.id).customer_number.should == 'ABC'
  end
  it 'should not update entry if older than last update' do
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    old_cust_num = @cust_num
    @cust_num = "nochange"
    @extract_date_str = '199901011226'  #make older
    #send file w/ older date & different cust num which should be ignored
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.count.should == 1
    Entry.first.customer_number.should == old_cust_num
  end
  it 'should populate entry header tracking fields' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    Entry.count.should == 1
    ent = Entry.first
    ent.master_bills_of_lading.should == (@si_lines.collect {|h| h[:mbol]}).join("\n")
    ent.house_bills_of_lading.should == (@si_lines.collect {|h| h[:hbol]}).join("\n")
    ent.sub_house_bills_of_lading.should == (@si_lines.collect {|h| h[:sub]}).join("\n")
    ent.it_numbers.should == (@si_lines.collect {|h| h[:it]}).join("\n")
  end
  it 'should replace entry header tracking fields' do
    Entry.create(:broker_reference=>@ref_num,:it_numbers=>'12345',:master_bills_of_lading=>'mbols',:house_bills_of_lading=>'bolsh',:sub_house_bills_of_lading=>'shs')
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    Entry.count.should == 1
    ent = Entry.first
    ent.master_bills_of_lading.should == (@si_lines.collect {|h| h[:mbol]}).join("\n")
    ent.house_bills_of_lading.should == (@si_lines.collect {|h| h[:hbol]}).join("\n")
    ent.sub_house_bills_of_lading.should == (@si_lines.collect {|h| h[:sub]}).join("\n")
    ent.it_numbers.should == (@si_lines.collect {|h| h[:it]}).join("\n")
  end
  it 'should create invoice' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.suffix.should == @inv_suffix
    inv.invoice_date.should == Date.parse(@inv_invoice_date_str)
    inv.invoice_total.should == @inv_total
    inv.customer_number.should == @cust_num
    inv.bill_to_name.should == @inv_b_name
    inv.bill_to_address_1.should == @inv_b_add_1
    inv.bill_to_address_2.should == @inv_b_add_2
    inv.bill_to_city.should == @inv_b_city
    inv.bill_to_zip.should == @inv_b_zip
    inv.bill_to_country.should == @country
  end
  it 'should update invoice' do
    # first invoice
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.suffix.should == @inv_suffix
    inv.invoice_total.should == @inv_total

    #second invoice (update)
    @inv_total = BigDecimal("99.09",2)
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.suffix.should == @inv_suffix
    inv.invoice_total.should == @inv_total
  end
  it 'should add invoice with different suffix' do
    entry = @make_entry_lambda.call
    inv_1 = @make_invoice_lambda.call
    @inv_suffix = '02'
    inv_2 = @make_invoice_lambda.call
    OpenChain::AllianceParser.parse [entry,inv_1,inv_2].join("\n")
    ent = Entry.first
    ent.broker_invoices.should have(2).invoices
    ent.broker_invoices.where(:suffix=>'01').should have(1).invoice
    ent.broker_invoices.where(:suffix=>'02').should have(1).invoice
  end
  it 'should create invoice lines' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    lines = inv.broker_invoice_lines
    lines.should have(@invoice_lines.size).lines
    @invoice_lines.each do |src|
      line = inv.broker_invoice_lines.where(:charge_code=>src[:code]).first
      line.charge_description.should == src[:desc]
      line.charge_amount.should == src[:amt]
      line.vendor_name.should == src[:v_name]
      line.vendor_reference.should == src[:v_ref]
      line.charge_type.should == src[:type]
    end
  end
  it 'should rebuild invoice lines on invoice update' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    @invoice_lines.each {|src| src[:desc] = "newdesc"}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    lines = inv.broker_invoice_lines
    lines.should have(@invoice_lines.size).lines
    @invoice_lines.each do |src|
      line = inv.broker_invoice_lines.where(:charge_code=>src[:code]).first
      line.charge_description.should == src[:desc]
      line.charge_amount.should == src[:amt]
      line.vendor_name.should == src[:v_name]
      line.vendor_reference.should == src[:v_ref]
      line.charge_type.should == src[:type]
    end
  end
end
