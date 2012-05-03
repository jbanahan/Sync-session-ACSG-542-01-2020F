require 'spec_helper'

describe OpenChain::Report::ContainersReleased do
  before :each do
    importer = Factory(:company,:importer=>true)
    broker = Factory(:company,:broker=>true,:master=>true)
    @importer_user = Factory(:user,:entry_view=>true,:company=>importer)
    @importer_user.stub(:view_entries?).and_return(true)
    @broker_user = Factory(:user,:company=>broker)
    @broker_user.stub(:view_entries?).and_return(true)
    @e1 = Factory(:entry,:entry_number=>"31612354578",:importer_id=>importer.id,:container_numbers=>"A\nB\nC",:arrival_date=>1.day.ago,:release_date=>0.days.ago,:export_date=>3.days.ago)
    @e2 = Factory(:entry,:entry_number=>"31698545621",:customer_number=>"ABC",:container_numbers=>"D\nE\nF",:arrival_date=>20.days.ago,:release_date=>0.days.ago,:export_date=>3.days.ago)
  end
  it "should secure entries by run_by's company" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @importer_user
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 3 #4 total rows
    ["A",@e1.entry_number,@e1.release_date,@e1.arrival_date,@e1.export_date,@e1.first_release_date].each_with_index do |v,i|
      if v.respond_to? :strftime 
        sheet.row(1)[i].strftime("%Y%m%d").should == v.strftime("%Y%m%d")
      else
        sheet.row(1)[i].should == v
      end
    end
    sheet.row(2)[0].should == "B"
    sheet.row(3)[0].should == "C"
  end
  it "should print header rows" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @importer_user
    sheet = wb.worksheet 0
    [:ent_container_nums,:ent_entry_num,:ent_release_date,:ent_arrival_date,:ent_export_date,:ent_first_release].each_with_index do |v,i|
      sheet.row(0)[i].should == ModelField.find_by_uid(v).label
    end
  end
  it "should only allow users who can view entries" do
    User.any_instance.stub(:view_entries?).and_return(false)
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report User.new 
    sheet = wb.worksheet 0
    sheet.row(0)[0].should == "You do not have permission to run this report."
  end
  it "should not include lines without containers" do
    @e1.update_attributes(:container_numbers=>"")
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 3 #4 total rows
    (1..3).each {|i| sheet.row(i)[1].should == @e2.entry_number}
  end
  it "should take optional customer numbers parameter" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user, {'customer_numbers'=>['ABC','QQQQ']}
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 3 #4 total rows
    (1..3).each {|i| sheet.row(i)[1].should == @e2.entry_number}
  end
  it "should filter on arrival date start" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user, {'arrival_date_start'=>4.days.ago}
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 3 #4 total rows
    (1..3).each {|i| sheet.row(i)[1].should == @e1.entry_number}
  end
  it "should filter on arrival date end" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @broker_user, {'arrival_date_end'=>4.days.ago}
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 3 #4 total rows
    (1..3).each {|i| sheet.row(i)[1].should == @e2.entry_number}
  end
end
