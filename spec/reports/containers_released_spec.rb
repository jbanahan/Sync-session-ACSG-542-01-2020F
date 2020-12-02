describe OpenChain::Report::ContainersReleased do
  before :each do
    importer = create(:company, :importer=>true)
    broker = create(:company, :broker=>true, :master=>true)
    @importer_user = create(:user, :entry_view=>true, :company=>importer)
    allow(@importer_user).to receive(:view_entries?).and_return(true)
    @broker_user = create(:user, :company=>broker)
    allow(@broker_user).to receive(:view_entries?).and_return(true)
    @e1 = create(:entry, :entry_number=>"31612354578", :importer_id=>importer.id, :container_numbers=>"A\nB\nC", :arrival_date=>1.day.ago, :release_date=>0.days.ago, :export_date=>3.days.ago)
    @e2 = create(:entry, :entry_number=>"31698545621", :customer_number=>"ABC", :container_numbers=>"D\nE\nF", :arrival_date=>20.days.ago, :release_date=>0.days.ago, :export_date=>3.days.ago)
  end
  it "should secure entries by run_by's company" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @importer_user
    sheet = wb.worksheet 0
    expect(sheet.last_row_index).to eq(3) # 4 total rows
    ["A", @e1.entry_number, @e1.release_date, @e1.arrival_date, @e1.export_date, @e1.first_release_date].each_with_index do |v, i|
      if v.respond_to? :strftime
        expect(sheet.row(1)[i].strftime("%Y%m%d")).to eq(v.strftime("%Y%m%d"))
      else
        expect(sheet.row(1)[i]).to eq(v)
      end
    end
    expect(sheet.row(2)[0]).to eq("B")
    expect(sheet.row(3)[0]).to eq("C")
  end
  it "should print header rows" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @importer_user
    sheet = wb.worksheet 0
    [:ent_container_nums, :ent_entry_num, :ent_release_date, :ent_arrival_date, :ent_export_date, :ent_first_release].each_with_index do |v, i|
      expect(sheet.row(0)[i]).to eq(ModelField.find_by_uid(v).label)
    end
  end
  it "should only allow users who can view entries" do
    allow_any_instance_of(User).to receive(:view_entries?).and_return(false)
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report User.new
    sheet = wb.worksheet 0
    expect(sheet.row(0)[0]).to eq("You do not have permission to run this report.")
  end
  it "should not include lines without containers" do
    @e1.update_attributes(:container_numbers=>"")
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user
    sheet = wb.worksheet 0
    expect(sheet.last_row_index).to eq(3) # 4 total rows
    (1..3).each {|i| expect(sheet.row(i)[1]).to eq(@e2.entry_number)}
  end
  it "should take optional customer numbers parameter" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user, {'customer_numbers'=>['ABC', 'QQQQ']}
    sheet = wb.worksheet 0
    expect(sheet.last_row_index).to eq(3) # 4 total rows
    (1..3).each {|i| expect(sheet.row(i)[1]).to eq(@e2.entry_number)}
  end
  it "should filter on arrival date start" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user, {'arrival_date_start'=>4.days.ago}
    sheet = wb.worksheet 0
    expect(sheet.last_row_index).to eq(3) # 4 total rows
    (1..3).each {|i| expect(sheet.row(i)[1]).to eq(@e1.entry_number)}
  end
  it "should filter on arrival date end" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user, {'arrival_date_end'=>4.days.ago}
    sheet = wb.worksheet 0
    expect(sheet.last_row_index).to eq(3) # 4 total rows
    (1..3).each {|i| expect(sheet.row(i)[1]).to eq(@e2.entry_number)}
  end
end
