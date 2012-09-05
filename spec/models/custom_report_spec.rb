require 'spec_helper'
require 'spreadsheet'

describe CustomReport do

  before :each do
    @rpt = CustomReport.new
    def @rpt.run run_by, row_limit=nil
      write 0, 0, "MY HEADING"
      write 1, 0, "my data"
      write 1, 1, 7
      write_hyperlink 1, 2, "http://abc/def", "mylink"
      write 4, 4, "my row 4"
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
  end
end
