require 'spec_helper'

describe XlsMaker do
  context "date handling" do
    before :each do
      @entry = Factory(:entry,:first_it_date=>1.day.ago,:file_logged_date=>1.minute.ago)
      @u = Factory(:master_user,:entry_view=>true)
      @search = SearchSetup.create!(:name=>'t',:user=>@u,:module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date',:rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date',:rank=>2)
      @wb = XlsMaker.new.make_from_search(@search,@search.search)
    end
    it "should format dates with DATE_FORMAT" do
      @wb.worksheet(0).row(1).format(0).should == XlsMaker::DATE_FORMAT
    end
    it "should format date_time with DATE_TIME_FORMAT" do
      @wb.worksheet(0).row(1).format(1).should == XlsMaker::DATE_TIME_FORMAT 
    end
    it "should format date_time with DATE_FORMAT if no_time option is set" do
      @wb = XlsMaker.new(:no_time=>true).make_from_search(@search,@search.search)
      @wb.worksheet(0).row(1).format(1).should == XlsMaker::DATE_FORMAT
    end
  end

  context "add_header_row" do

    before :each do
      @wb = Spreadsheet::Workbook.new
      @sheet = @wb.create_worksheet :name => "Sheet"
    end

    it "should add a header row using HEADER FORMAT" do
      # Make sure we use the col_widths for a specific column if it's set, and don't 
      # just overwrite it
      col_widths = [nil, 15]
      
      XlsMaker.add_header_row @sheet, 1, ['Header', 'Header 2'], col_widths

      @sheet.row(1)[0].should == "Header"
      @sheet.row(1)[1].should == "Header 2"
      @sheet.row(1).default_format.should == XlsMaker::HEADER_FORMAT
      # 23 is the max width for header (by default 3 is added to the lenght if it's less than 23)
      col_widths[0].should == 9 
      col_widths[1].should == 15
    end

    it "should limit the header width to 23" do
      col_widths = [] 
      XlsMaker.add_header_row @sheet, 1, ['This is really long text that will be longer than 23 chars'], col_widths
      col_widths[0].should == 23
    end
  end

  context "add_body_row" do
    before :each do
      @wb = Spreadsheet::Workbook.new
      @sheet = @wb.create_worksheet :name => "Sheet"
    end

    it "should add a body row" do
      col_widths = []
      date = DateTime.now.to_date
      datetime = Time.now

      XlsMaker.add_body_row @sheet, 1, ["Test", date, datetime], col_widths

      @sheet.row(1)[0].should == "Test"
      @sheet.row(1)[1].should == date
      @sheet.row(1)[2].should == datetime

      col_widths[0].should == 8
      col_widths[1].should == 13
      col_widths[2].should == datetime.to_s.size + 3

      @sheet.row(1).formats[1].should == XlsMaker::DATE_FORMAT
      @sheet.row(1).formats[2].should == XlsMaker::DATE_TIME_FORMAT
    end

    it "should force date format for datetimes" do 
      col_widths = []
      XlsMaker.add_body_row @sheet, 1, [Time.now], col_widths, true
      col_widths[0].should == 13
      @sheet.row(1).formats[0].should == XlsMaker::DATE_FORMAT
    end
  end
end

