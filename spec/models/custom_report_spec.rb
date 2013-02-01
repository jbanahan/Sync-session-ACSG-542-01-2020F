require 'spec_helper'
require 'spreadsheet'

describe CustomReport do

  describe :give_to do
    before :each do
      @u = Factory(:user,:first_name=>"A",:last_name=>"B")
      @u2 = Factory(:user)
      @s = CustomReportEntryInvoiceBreakdown.create!(:name=>"ABC",:user=>@u,:include_links=>true)
    end
    it "should copy to another user" do
      @s.give_to @u2
      d = CustomReport.find_by_user_id @u2.id
      d.name.should == "ABC (From #{@u.full_name})"
      d.id.should_not be_nil
      d.class.should == CustomReportEntryInvoiceBreakdown
      @s.reload
      @s.name.should == "ABC" #we shouldn't modify the original object
    end
  end
  describe :deep_copy do
    before :each do 
      @u = Factory(:user)
      @s = CustomReportEntryInvoiceBreakdown.create!(:name=>"ABC",:user=>@u,:include_links=>true)
    end
    it "should copy basic search setup" do
      d = @s.deep_copy "new"
      d.id.should_not be_nil
      d.id.should_not == @s.id
      d.name.should == "new"
      d.user.should == @u
      d.include_links.should be_true
      d.class.should == CustomReportEntryInvoiceBreakdown
    end
    it "should copy parameters" do
      @s.search_criterions.create!(:model_field_uid=>'a',:value=>'x',:operator=>'y',:status_rule_id=>1,:custom_definition_id=>2)
      d = @s.deep_copy "new"
      d.should have(1).search_criterions
      sc = d.search_criterions.first
      sc.model_field_uid.should == 'a'
      sc.value.should == 'x'
      sc.operator.should == 'y'
      sc.status_rule_id.should == 1
      sc.custom_definition_id.should == 2
    end
    it "should copy columns" do
      @s.search_columns.create!(:model_field_uid=>'a',:rank=>7,:custom_definition_id=>9)
      d = @s.deep_copy "new"
      d.should have(1).search_column
      sc = d.search_columns.first
      sc.model_field_uid.should == 'a'
      sc.rank.should == 7
      sc.custom_definition_id.should == 9
    end
    it "should not copy schedules" do
      @s.search_schedules.create!
      d = @s.deep_copy "new"
      d.search_schedules.should be_empty
    end
  end
  context :report_output do
    before :each do
      @rpt = CustomReport.new
      def @rpt.run run_by, row_limit=nil
        write 0, 0, "MY HEADING"
        write 1, 0, "my data"
        write 1, 1, 7
        write_hyperlink 1, 2, "http://abc/def", "mylink"
        write 4, 4, "my row 4"
        write_columns 5, 1, ["col1", "col2"]
        heading_row 0
      end
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it 'should output xls to tmp file' do
      @tmp = @rpt.xls_file Factory(:user)
      @tmp.path.should match(/xls/)
      sheet = Spreadsheet.open(@tmp.path).worksheet(0)
      sheet.row(0).default_format.name.should == XlsMaker::HEADER_FORMAT.name
      sheet.row(0)[0].should == "MY HEADING"
      sheet.row(1)[0].should == "my data"
      sheet.row(1)[1].should == 7
      sheet.row(1)[2].should == "mylink"
      sheet.row(1)[2].url.should == "http://abc/def"
      sheet.row(4)[4].should == "my row 4"
      sheet.row(5)[1].should == "col1"
      sheet.row(5)[2].should == "col2"
    end
    it 'should output to given xls file' do
      @tmp = Tempfile.new('custom_report_spec')
      t = @rpt.xls_file Factory(:user), @tmp
      t.path.should == @tmp.path
      sheet = Spreadsheet.open(@tmp.path).worksheet(0)
      sheet.row(0)[0].should == "MY HEADING"
    end

    it 'should output to array of arrays' do
      r = @rpt.to_arrays Factory(:user)
      r[0][0].should == "MY HEADING"
      r[1][0].should == "my data"
      r[1][1].should == 7
      r[1][2].should == "http://abc/def"
      r[2].should have(0).elements
      r[3].should have(0).elements
      r[4][0].should == ""
      r[4][4].should == "my row 4"
      r[5].should == ["", "col1", "col2"]
    end

    it 'should output csv' do
      @tmp = @rpt.csv_file Factory(:user)
      @tmp.path.should match(/csv/)
      r = CSV.read @tmp.path
      r[0][0].should == "MY HEADING"
      r[1][0].should == "my data"
      r[1][1].should == "7"
      r[1][2].should == "http://abc/def"
      r[2].should have(0).elements
      r[3].should have(0).elements
      r[4][0].should == ""
      r[4][4].should == "my row 4"
      r[5].should == ["", "col1", "col2"]
    end
  end
end
