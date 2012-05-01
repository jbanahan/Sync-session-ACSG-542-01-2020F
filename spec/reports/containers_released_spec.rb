require 'spec_helper'

describe OpenChain::Report::ContainersReleased do
  before :each do
    importer = Factory(:company,:importer=>true)
    broker = Factory(:company,:broker=>true)
    @importer_user = Factory(:user,:entry_view=>true,:company=>importer)
    @e1 = Factory(:entry,:entry_number=>"31612354578",:importer_id=>importer.id,:container_numbers=>"A\nB\nC",:arrival_date=>1.day.ago,:release_date=>0.days.ago,:export_date=>3.days.ago)
    @e2 = Factory(:entry,:entry_number=>"31698545621",:container_numbers=>"D\nE\nF",:arrival_date=>1.day.ago,:release_date=>0.days.ago,:export_date=>3.days.ago)
  end
  it "should secure entries by run_by's company" do
    wb = Spreadsheet.open OpenChain::Report::ContainersReleased.run_report @importer_user
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 3 #4 total rows
    ["A",@e1.entry_number,@e1.release_date,@e1.arrival_date,@e1.export_date,@e1.first_release_date].each_with_index do |v,i|
      sheet.row(1)[i].should == v
    end
    sheet.row(2)[0].should == "B"
    sheet.row(3)[0].should == "C"
  end
  it "should only allow users who can view entries"
  it "should make one line per container"
  it "should not include lines without containers"
  it "should take optional customer numbers parameter"
  it "should filter on arrival date start"
  it "should filter on arrival date end"
end
