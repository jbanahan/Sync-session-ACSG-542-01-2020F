require 'spec_helper'

describe OpenChain::Report::EddieBauerStatementSummary do
  before :each do
    @user = Factory(:user)
    @imp = Factory(:company,:alliance_customer_number=>"EDDIE")
    @monthly_date = 0.seconds.ago
    @daily_date = 1.day.ago
    @ent = Factory(:entry,:importer=>@imp,
      :daily_statement_number=>'123456',
      :monthly_statement_number=>'MSTMT',
      :monthly_statement_received_date=>@monthly_date,
      :daily_statement_approved_date=>@daily_date,
      :entry_number => "31612345678")
    @po_number = 'E0427291-0011'
    @invoice_number = 'INV1234'
    @line = Factory(:commercial_invoice_line,
      :commercial_invoice=>Factory(:commercial_invoice,:entry=>@ent,:invoice_number=>@invoice_number),
      :po_number=>@po_number,
      :prorated_mpf => BigDecimal("10.50"),
      :hmf=>BigDecimal("20.00"),
      :cotton_fee=>BigDecimal("2.10"))
    @tar = @line.commercial_invoice_tariffs.create!(:duty_rate=>BigDecimal("0.081"),
      :duty_amount=>BigDecimal("12.22"))
    Entry.any_instance.stub(:can_view?).and_return(true)
  end
  after :each do
    @tmp.unlink if @tmp
  end
  it "should raise exception if user cannot view returned entries" do
    Entry.any_instance.stub(:can_view?).and_return(false)
    lambda {described_class.run_report @user}.should raise_error "You do not have permission to view the entries related to this report." 
  end

  def get_details_tab
    @tmp = described_class.run_report @user
    wb = Spreadsheet.open @tmp
    wb.worksheet 1
  end
  def get_summary_tab
    @tmp = described_class.run_report @user
    wb = Spreadsheet.open @tmp
    wb.worksheet 0
  end
  it "should populate details tab" do
    sheet = get_details_tab
    sheet.last_row_index.should == 1
    r = sheet.row(1)
    r[0].should == @ent.monthly_statement_number
    r[1].should == @ent.daily_statement_number
    r[2].should == @ent.entry_number
    r[3].should == 'E0427291'
    r[4].should == '0011'
    r[5].should == @invoice_number
    r[6].should == @tar.duty_rate.to_f*100
    r[7].should == @tar.duty_amount.to_f
    r[8].should == 32.6
    r[9].strftime("%Y%m%d").should == @ent.daily_statement_approved_date.strftime("%Y%m%d")
    r[10].strftime("%Y%m%d").should == @ent.monthly_statement_received_date.strftime("%Y%m%d")
    r[11].should == "31612345678/8.1/INV1234"
  end
  it "should write details headings" do
    r = get_details_tab.row(0)
    headings = ["Statement #", 
      "ACH #", "Entry #", "PO", "Business", "Invoice", 
      "Duty Rate", "Duty", "Taxes / Fees", "ACH Date","Statement Date","Unique ID"]
    headings.each_with_index do |h,i|
      r[i].should == h
    end
  end
  it "should return entries not paid on PMS but on daily statement" do
    dont_find_because_paid = Factory(:entry,:importer=>@imp,
      :daily_statement_number=>'123456',:monthly_statement_paid_date=>Time.now)
    dont_find_because_not_on_daily = Factory(:entry,:importer=>@imp) 
    dont_find_because_not_eddie = Factory(:entry,:daily_statement_number=>'12345')
    described_class.new(@user).find_entries.to_a.should == [@ent]
  end
  it "should total lines if multiple tariff records (and use higher duty rate)" do
    @line.commercial_invoice_tariffs.create!(:duty_rate=>BigDecimal("0.06"),
      :duty_amount=>BigDecimal("1"))
      r = get_details_tab.row(1)
      r[6].should == @tar.duty_rate.to_f*100
      r[7].should == BigDecimal("13.22").to_f
  end
  it "should create summary tab" do
    e2 = Factory(:entry,:importer=>@imp,
      :daily_statement_number=>'6555',
      :monthly_statement_number=>@ent.monthly_statement_number,
      :monthly_statement_received_date=>@ent.monthly_statement_received_date,
      :daily_statement_approved_date=>2.weeks.ago,
      :entry_number=>'316555555555'
    )
    l2 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:entry=>e2,:invoice_number=>'123'),
      :po_number=>'E123-0011',:prorated_mpf=>BigDecimal("10.00"),:hmf=>BigDecimal("20.00"),
      :cotton_fee=>BigDecimal("5.00")
    )
    t2 = l2.commercial_invoice_tariffs.create!(:duty_rate=>BigDecimal("0.088"),
      :duty_amount=>BigDecimal("4.00")
    )
    l3 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:entry=>e2,:invoice_number=>'123'),
      :po_number=>'E123-0099',:prorated_mpf=>BigDecimal("10.00"),:hmf=>BigDecimal("20.00"),
      :cotton_fee=>BigDecimal("5.00")
    )
    l3.commercial_invoice_tariffs.create!(:duty_rate=>BigDecimal("0.088"),
      :duty_amount=>BigDecimal("6.00")
    )
    tab = get_summary_tab 
    tab.last_row_index.should == 2
    r = tab.row(1)
    r[0].should == @ent.monthly_statement_number
    r[1].should == "0011"
    r[2].should == 16.22
    r[3].should == 67.60
    r[4].strftime("%Y%m%d").should == @ent.monthly_statement_received_date.strftime("%Y%m%d")
    r = tab.row(2)
    r[0].should == @ent.monthly_statement_number
    r[1].should == "0099"
    r[2].should == 6.00
    r[3].should == 35.00
  end
  it "should write Summary headings" do
    r = get_summary_tab.row(0)
    headings = ["Statement #", "Business", "Duty", "Taxes / Fees", "Statement Date"]
    headings.each_with_index do |h,i|
      r[i].should == h
    end
  end
end
