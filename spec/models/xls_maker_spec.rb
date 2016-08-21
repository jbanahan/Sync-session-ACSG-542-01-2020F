require 'spec_helper'

describe XlsMaker do

  describe "make_from_search_query" do
    before :each do
      @u = Factory(:master_user,:entry_view=>true)
      @search = SearchSetup.create!(:name=>'t',:user=>@u,:module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_brok_ref',:rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_entry_num',:rank=>2)
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date',:rank=>3)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date',:rank=>4)
      @search.search_criterions.create! model_field_uid: 'ent_brok_ref', operator: "eq", value: "x"
      @sq = SearchQuery.new @search, @u
      allow(@sq).to receive(:execute).
        and_yield({:row_key=>1,:result=>['a','b',Date.new(2013,4,30),Time.now]}).
        and_yield({:row_key=>2,:result=>['c','d',Date.new(2013,4,30),Time.now]})
    end
    it "should create workbook" do
      wb, data_row_count = XlsMaker.new.make_from_search_query @sq
      expect(data_row_count).to eq(2)
      s = wb.worksheet(0)
      expect(s.row(1)[0]).to eq('a')
      expect(s.row(1)[1]).to eq('b')
      expect(s.row(2)[0]).to eq('c')
      expect(s.row(2)[1]).to eq('d')
    end
    it "should count 0 rows when workbook is empty" do
       allow(@sq).to receive(:execute).and_return nil
       *, data_row_count = XlsMaker.new.make_from_search_query @sq
       expect(data_row_count).to eq 0
    end
    it "should write headings" do
      wb, * = XlsMaker.new.make_from_search_query @sq
      s = wb.worksheet(0)
      r = s.row(0)
      expect(r[0]).to eq(ModelField.find_by_uid(:ent_brok_ref).label)
      expect(r[1]).to eq(ModelField.find_by_uid(:ent_entry_num).label)
      expect(r[2]).to eq(ModelField.find_by_uid(:ent_first_it_date).label)
      expect(r[3]).to eq(ModelField.find_by_uid(:ent_file_logged_date).label)
    end
    it "should format dates with DATE_FORMAT" do
      wb, * = XlsMaker.new.make_from_search_query @sq
      expect(wb.worksheet(0).row(1).format(2)).to eq(XlsMaker::DATE_FORMAT)
    end
    it "should format date_time with DATE_TIME_FORMAT" do
      wb, * = XlsMaker.new.make_from_search_query @sq
      expect(wb.worksheet(0).row(1).format(3)).to eq(XlsMaker::DATE_TIME_FORMAT) 
    end
    it "should format date_time with DATE_FORMAT if no_time option is set" do
      wb, * = XlsMaker.new(:no_time=>true).make_from_search_query @sq
      expect(wb.worksheet(0).row(1).format(3)).to eq(XlsMaker::DATE_FORMAT)
    end
    it "should add web links" do
      allow_any_instance_of(Entry).to receive(:excel_url).and_return("abc")
      expect(Entry).to receive(:find).with(1).and_return(Entry.new(:id=>1))
      expect(Entry).to receive(:find).with(2).and_return(Entry.new(:id=>2))
      wb, * = XlsMaker.new(:include_links=>true).make_from_search_query @sq
      s = wb.worksheet(0)
      expect(s.row(1)[4]).to be_a Spreadsheet::Link
    end
    it "raises an error if the search is not downloadable" do
      expect(@sq.search_setup).to receive(:downloadable?).with(instance_of(Array), true) {|e| e << "Error!"; false}
      expect {XlsMaker.new.make_from_search_query @sq, single_page: true}.to raise_error "Error!"
    end

    it "raises an error if the maximum number of results is exceeded" do
      allow(@sq.search_setup).to receive(:max_results).and_return 1
      expect {XlsMaker.new.make_from_search_query @sq}.to raise_error "Your report has over 1 rows.  Please adjust your parameter settings to limit the size of the report."
    end
  end
  describe "make_from_search_query_by_search_id_and_user_id" do
    it "should defer to normal method" do
      ss = double('ss')
      u = double('u')
      sq = double('sq')
      expect(SearchSetup).to receive(:find).with(1).and_return(ss)
      expect(User).to receive(:find).with(2).and_return(u)
      expect(SearchQuery).to receive(:new).with(ss,u).and_return(sq)
      xm = XlsMaker.new
      expect(xm).to receive(:make_from_search_query).with(sq).and_return('x')
      r = xm.make_from_search_query_by_search_id_and_user_id 1, 2
      expect(r).to eq('x')
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

      expect(@sheet.row(1)[0]).to eq("Header")
      expect(@sheet.row(1)[1]).to eq("Header 2")
      expect(@sheet.row(1).default_format).to eq(XlsMaker::HEADER_FORMAT)
      # 23 is the max width for header (by default 3 is added to the lenght if it's less than 23)
      expect(col_widths[0]).to eq(9) 
      expect(col_widths[1]).to eq(15)
    end

    it "should limit the header width to 23" do
      col_widths = [] 
      XlsMaker.add_header_row @sheet, 1, ['This is really long text that will be longer than 23 chars'], col_widths
      expect(col_widths[0]).to eq(23)
    end

    it "handles headers that are not string values" do
      XlsMaker.add_header_row @sheet, 1, [1, Date.new(2016,1,1)], []
      expect(@sheet.row(1)[0]).to eq "1"
      expect(@sheet.row(1)[1]).to eq "2016-01-01"
      expect(@sheet.row(1).default_format).to eq XlsMaker::HEADER_FORMAT
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

      expect(@sheet.row(1)[0]).to eq("Test")
      expect(@sheet.row(1)[1]).to eq(date)
      expect(@sheet.row(1)[2]).to eq(datetime)

      expect(col_widths[0]).to eq(8)
      expect(col_widths[1]).to eq(13)
      expect(col_widths[2]).to eq(datetime.to_s.size + 3)

      expect(@sheet.row(1).formats[1]).to eq(XlsMaker::DATE_FORMAT)
      expect(@sheet.row(1).formats[2]).to eq(XlsMaker::DATE_TIME_FORMAT)
    end

    it "should force date format for datetimes" do 
      col_widths = []
      XlsMaker.add_body_row @sheet, 1, [Time.now], col_widths, true
      expect(col_widths[0]).to eq(13)
      expect(@sheet.row(1).formats[0]).to eq(XlsMaker::DATE_FORMAT)
    end

    it "should use given format" do
      XlsMaker.add_body_row @sheet, 1, ["Test"], [], false, format: Spreadsheet::Format.new(pattern_fg_color: :yellow, pattern: 1)
      expect(@sheet.row(1).formats[0].pattern_fg_color).to eq :yellow
    end
  end

  context :insert_body_row do
    before :each do
      @wb = Spreadsheet::Workbook.new
      @sheet = @wb.create_worksheet :name => "Sheet"
    end

    it "should insert a row starting at the column specified" do 
      col_widths = []
      date = DateTime.now.to_date
      datetime = Time.now

      XlsMaker.insert_body_row @sheet, 1, 1, ["Test", date, datetime], col_widths

      expect(@sheet.row(1)[0]).to be_nil
      expect(@sheet.row(1)[1]).to eq("Test")
      expect(@sheet.row(1)[2]).to eq(date)
      expect(@sheet.row(1)[3]).to eq(datetime)

      expect(col_widths[1]).to eq(8)
      expect(col_widths[2]).to eq(13)
      expect(col_widths[3]).to eq(datetime.to_s.size + 3)

      expect(@sheet.row(1).formats[2]).to eq(XlsMaker::DATE_FORMAT)
      expect(@sheet.row(1).formats[3]).to eq(XlsMaker::DATE_TIME_FORMAT)
    end

    it "should insert a row starting at the column specified and push back existing columns" do 
      col_widths = []
      date = DateTime.now.to_date
      datetime = Time.now

      XlsMaker.add_body_row @sheet, 1, ["A", "D", "E"]

      XlsMaker.insert_body_row @sheet, 1, 1, ["B", "C"]

      expect(@sheet.row(1)[0]).to eq("A")
      expect(@sheet.row(1)[1]).to eq("B")
      expect(@sheet.row(1)[2]).to eq("C")
      expect(@sheet.row(1)[3]).to eq("D")
      expect(@sheet.row(1)[4]).to eq("E")
    end

    it "should force date format for datetimes" do 
      col_widths = []
      XlsMaker.insert_body_row @sheet, 1, 0, [Time.now], col_widths, true
      expect(col_widths[0]).to eq(13)
      expect(@sheet.row(1).formats[0]).to eq(XlsMaker::DATE_FORMAT)
    end
  end

  describe "insert_cell_value" do
    before :each do
      @wb = Spreadsheet::Workbook.new
      @sheet = @wb.create_worksheet :name => "Sheet"
    end

    it "adds a cell to the sheet" do
      widths = []
      XlsMaker.insert_cell_value @sheet, 0, 0, "Test12", widths
      expect(@sheet.row(0)[0]).to eq "Test12"
      expect(widths[0]).to eq 9
    end

    it "makes all widths be at least 8" do
      widths = []
      XlsMaker.insert_cell_value @sheet, 0, 0, "T", widths
      expect(@sheet.row(0)[0]).to eq "T"
      expect(widths[0]).to eq 8
    end

    it "maxes out widths at 23" do
      widths = []
      XlsMaker.insert_cell_value @sheet, 0, 0, "1234567890123456789012345", widths
      expect(@sheet.row(0)[0]).to eq "1234567890123456789012345"
      expect(widths[0]).to eq 23
    end

    it "doesn't change widths when new width is smaller than an existing stored one" do
      widths = [10]
      XlsMaker.insert_cell_value @sheet, 0, 0, "T", widths
      expect(@sheet.row(0)[0]).to eq "T"
      expect(widths[0]).to eq 10
    end

    it "adds a blank value to the sheet for nil" do
      XlsMaker.insert_cell_value @sheet, 0, 0, nil
      expect(@sheet.row(0)[0]).to eq ""
    end

    it "formats dates correctly" do
      XlsMaker.insert_cell_value @sheet, 0, 0, Date.new(2014, 01, 01)
      expect(@sheet.row(0)[0].to_s).to eq Date.new(2014, 01, 01).to_s
      expect(@sheet.row(0).formats[0].number_format).to eq "YYYY-MM-DD"
    end

    it "formats times correctly" do
      XlsMaker.insert_cell_value @sheet, 0, 0, Time.new(2014, 01, 01)
      expect(@sheet.row(0)[0].to_s).to eq Time.new(2014, 01, 01).to_s
      expect(@sheet.row(0).formats[0].number_format).to eq "YYYY-MM-DD HH:MM"
    end

    it "formats DateTimes correctly" do
      XlsMaker.insert_cell_value @sheet, 0, 0, DateTime.new(2014, 01, 01)
      expect(@sheet.row(0)[0].to_s).to eq DateTime.new(2014, 01, 01).to_s
      expect(@sheet.row(0).formats[0].number_format).to eq "YYYY-MM-DD HH:MM"
    end

    it "respects the no_time option" do 
      XlsMaker.insert_cell_value @sheet, 0, 0, Time.new(2014, 01, 01), [], {no_time: true}
      expect(@sheet.row(0)[0].to_s).to eq Time.new(2014, 01, 01).to_s
      expect(@sheet.row(0).formats[0].number_format).to eq "YYYY-MM-DD"
    end

    it "shifts existing data to the right" do
      @sheet.row(0)[0] = "Test"
      XlsMaker.insert_cell_value @sheet, 0, 0, "Test2"
      expect(@sheet.row(0)[0]).to eq "Test2"
      expect(@sheet.row(0)[1]).to eq "Test"
    end

    it "appends to the end of the row if insert is false" do
      @sheet.row(0)[0] = "Test"
      XlsMaker.insert_cell_value @sheet, 0, 0, "Test2", [], {:insert=> false}
      expect(@sheet.row(0)[0]).to eq "Test"
      expect(@sheet.row(0)[1]).to eq "Test2"
    end

    it "handles appending date formats correctly and updating column widths" do
      widths = []
      @sheet.row(0)[0] = "Test"
      XlsMaker.insert_cell_value @sheet, 0, 0, Time.new(2014, 01, 01), widths, {:insert=> false}
      expect(widths[1]).to eq 19
      expect(@sheet.row(0).formats[1].number_format).to eq "YYYY-MM-DD HH:MM"
    end

    it "handles format overrides" do
      XlsMaker.insert_cell_value @sheet, 0, 0, Time.new(2014, 01, 01), [], {no_time: true, :format => Spreadsheet::Format.new(:number_format=>'MM/DD/YYYY')}
      expect(@sheet.row(0)[0].to_s).to eq Time.new(2014, 01, 01).to_s
      expect(@sheet.row(0).formats[0].number_format).to eq "MM/DD/YYYY"
    end
  end

  describe "create_workbook" do
    it "creates a new workbook" do
      wb = XlsMaker.create_workbook "Sheet", ["Header"]
      s = wb.worksheet "Sheet"
      expect(s).to_not be_nil
      expect(s.row(0)[0]).to eq "Header"
      expect(s.row(0).format 0).to eq XlsMaker::HEADER_FORMAT
    end
  end

  describe "create_sheet" do
    it "creates a new worksheet from an existing book" do
      wb = XlsMaker.create_workbook "Sheet", ["Header"]
      s = XlsMaker.create_sheet wb, "Sheet2", ["Header2"]

      expect(s).to_not be_nil
      expect(s.row(0)[0]).to eq "Header2"
      expect(s.row(0).format 0).to eq XlsMaker::HEADER_FORMAT
    end
  end

  describe "create_link_cell" do
    it "creates a link cell" do
      expect(XlsMaker.create_link_cell("url")).to eq Spreadsheet::Link.new("url", "Web View")
    end

    it "creates a link cell with given text" do
      expect(XlsMaker.create_link_cell("url", "Test")).to eq Spreadsheet::Link.new("url", "Test")
    end
  end

  describe "excel_url" do
    it "wraps the given relative url in a redirect" do
      allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "localhost"
      expect(XlsMaker.excel_url("/page.html?a=1&b=2")).to eq "http://localhost/redirect.html?page=#{CGI.escape("/page.html?a=1&b=2")}"
    end
  end

  describe "create_workbook_and_sheet" do
    it "creates and returns a workbook and sheet object" do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Test", ["Header", "Header 2"]
      expect(wb.worksheet(0)).to eq sheet
      expect(sheet.name).to eq "Test"
      expect(sheet.row(0)).to eq ["Header", "Header 2"]
      expect(sheet.row(0).format 0).to eq XlsMaker::HEADER_FORMAT
    end
  end

  describe "set_column_widths" do
    it "sets the given widths as the columns widths for the sheet" do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Test", ["Header", "Header 2"]
      col0 = sheet.column(0).width
      col2 = sheet.column(2).width
      XlsMaker.set_column_widths sheet, [nil, 1, -1, 0]
      expect(sheet.column(0).width).to eq col0
      expect(sheet.column(1).width).to eq 1
      expect(sheet.column(2).width).to eq col2
      expect(sheet.column(3).width).to eq 0
    end
  end

  describe "set_cell_formats" do
    it "sets the formats in the array as the cells formats" do
      wb, sheet = XlsMaker.create_workbook_and_sheet "Test", ["Header", "Header 2"]
      format = XlsMaker.create_format "Test"
      XlsMaker.set_cell_formats sheet, 1, [format, nil, format]

      row = sheet.row(1)
      expect(row.format(0).try :name).to eq "Test"
      expect(row.format(1).try :name).to be_nil
      expect(row.format(2).try :name).to eq "Test"
    end
  end

  describe "create_format" do
    it "creates a new spreadsheet format and sets the name" do
      format = XlsMaker.create_format "Test", weight: :bold, color: :black, name: "Helvetica", number_format: "0.00"
      expect(format.name).to eq "Test"
      expect(format.font.name).to eq "Helvetica"
      expect(format.font.color).to eq :black
      expect(format.font.weight).to eq :bold
      expect(format.number_format).to eq "0.00"
    end
  end
end

