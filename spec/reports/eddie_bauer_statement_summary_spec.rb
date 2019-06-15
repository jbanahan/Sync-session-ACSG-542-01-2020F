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
      :entry_number => "31612345678",
      :release_date=>1.month.ago)
    @po_number = 'E0427291-0011'
    @invoice_number = 'INV1234'
    @line = Factory(:commercial_invoice_line,
      :commercial_invoice=>Factory(:commercial_invoice,:entry=>@ent,:invoice_number=>@invoice_number),
      :country_origin_code=>'CN',
      :po_number=>@po_number,
      :prorated_mpf => BigDecimal("10.50"),
      :hmf=>BigDecimal("20.00"),
      :cotton_fee=>BigDecimal("2.10"))
    @tar = @line.commercial_invoice_tariffs.create!(:duty_rate=>BigDecimal("0.081"),
      :duty_amount=>BigDecimal("12.22"))
    allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
    allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "www.test.com"
  end
  after :each do
    @tmp.unlink if @tmp
  end
  it "should raise exception if user cannot view returned entries" do
    allow_any_instance_of(Entry).to receive(:can_view?).and_return(false)
    expect {described_class.run_report @user, customer_number: @imp.alliance_customer_number}.to raise_error "You do not have permission to view the entries related to this report." 
  end

  def get_summary_tab
    get_spreadsheet.worksheet 0
  end

  def get_details_tab
    get_spreadsheet.worksheet 1
  end

  def get_spreadsheet 
    @tmp = described_class.run_report @user, customer_number: @imp.alliance_customer_number
    Spreadsheet.open @tmp
  end
  
  it "should populate details tab" do
    sheet = get_details_tab
    expect(sheet.last_row_index).to eq(1)
    r = sheet.row(1)
    expect(r[0]).to eq(@ent.monthly_statement_number)
    expect(r[1]).to eq(@ent.daily_statement_number)
    expect(r[2]).to eq(@ent.entry_number)
    expect(r[3]).to eq('E0427291')
    expect(r[4]).to eq('0011')
    expect(r[5]).to eq(@invoice_number)
    expect(r[6]).to eq(@tar.duty_rate.to_f*100)
    expect(r[7]).to eq(@tar.duty_amount.to_f)
    expect(r[8]).to eq(32.6)
    expect(r[9].strftime("%Y%m%d")).to eq(@ent.daily_statement_approved_date.strftime("%Y%m%d"))
    expect(r[10].strftime("%Y%m%d")).to eq(@ent.monthly_statement_received_date.strftime("%Y%m%d"))
    expect(r[11].strftime("%Y%m%d")).to eq(@ent.release_date.strftime("%Y%m%d"))
    expect(r[12]).to eq("31612345678/8.1/INV1234")
    expect(r[13]).to eq "CN"
  end
  it "should write details headings" do
    r = get_details_tab.row(0)
    headings = ["Statement #", 
      "ACH #", "Entry #", "PO", "Business", "Invoice", 
      "Duty Rate", "Duty", "Taxes / Fees", "ACH Date","Statement Date","Release Date","Unique ID", "Country of Origin"]
    headings.each_with_index do |h,i|
      expect(r[i]).to eq(h)
    end
  end
  context "default mode (not_paid)" do
    it "should return entries not paid on PMS but on daily statement" do
      dont_find_because_paid = Factory(:entry,:importer=>@imp,
        :daily_statement_number=>'123456',:monthly_statement_paid_date=>Time.now)
      dont_find_because_not_on_daily = Factory(:entry,:importer=>@imp) 
      dont_find_because_not_eddie = Factory(:entry,:daily_statement_number=>'12345')
      expect(described_class.new(@user).find_entries(@imp).to_a).to eq([@ent])
    end
  end
  context "previous_month mode" do
    it "should return entries from month / year specified regardless of paid status" do
      find_even_though_paid = Factory(:entry,:importer=>@imp,:monthly_statement_paid_date=>Time.now,:release_date=>((Time.zone.now - 3.months) + 1.minute).in_time_zone("America/New_York"))
      @ent.update_attributes!(:release_date=>(Time.zone.now - 3.months).in_time_zone("America/New_York"))
      dont_find_even_though_unpaid_because_different_month = Factory(:entry,:importer=>@imp,:release_date=>1.hour.from_now.in_time_zone("America/New_York"))
      options = {:mode => 'previous_month', :month => find_even_though_paid.release_date.month, :year => find_even_though_paid.release_date.year, :customer_number=>@imp.alliance_customer_number}
      ent = described_class.new(@user,options)
      expect(ent.find_entries(@imp).map(&:id)).to eq([@ent,find_even_though_paid].map(&:id))
    end
  end
  it "should total lines if multiple tariff records (and use higher duty rate)" do
    @line.commercial_invoice_tariffs.create!(:duty_rate=>BigDecimal("0.06"),
      :duty_amount=>BigDecimal("1"))
      r = get_details_tab.row(1)
      expect(r[6]).to eq(@tar.duty_rate.to_f*100)
      expect(r[7]).to eq(BigDecimal("13.22").to_f)
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
    expect(tab.last_row_index).to eq(2)
    r = tab.row(1)
    expect(r[0]).to eq(@ent.monthly_statement_number)
    expect(r[1]).to eq("0011")
    expect(r[2]).to eq(16.22)
    expect(r[3]).to eq(67.60)
    expect(r[4].strftime("%Y%m%d")).to eq(@ent.monthly_statement_received_date.strftime("%Y%m%d"))
    r = tab.row(2)
    expect(r[0]).to eq(@ent.monthly_statement_number)
    expect(r[1]).to eq("0099")
    expect(r[2]).to eq(6.00)
    expect(r[3]).to eq(35.00)
  end
  it "should write Summary headings" do
    r = get_summary_tab.row(0)
    headings = ["Statement #", "Business", "Duty", "Taxes / Fees", "Statement Date"]
    headings.each_with_index do |h,i|
      expect(r[i]).to eq(h)
    end
  end
end
