require 'spec_helper'

describe OpenChain::Report::ReportHelper do

  before :each do 
    @helper = Class.new do
        include OpenChain::Report::ReportHelper

        def run query, conversions = {}
          wb = Spreadsheet::Workbook.new
          s = wb.create_worksheet :name=>'x'
          table_from_query s, query, conversions
        end
      end
  end
  
  describe "table_from_query" do
    it "runs a query, adds headers to sheet, passing control to write result sheet" do
      q = "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      h = @helper.new
      # We can't really reliably determine result set, since there is no ActiveRecord base for it
      # so just detect it as something that responds to each, since that's how the method handles it anyway.
      h.should_receive(:write_result_set_to_sheet).with(duck_type(:each), instance_of(Spreadsheet::Worksheet), ['EN','IDENT'], 1, {}).and_return 48
      expect(h.run q).to eq 48
    end
  end

  describe "write_result_set_to_sheet" do

    before :each do 
      @wb = XlsMaker.create_workbook 'test'
      @sheet = @wb.worksheets[0]
    end

    it "should write results to the given sheet" do
      e1 = Factory(:entry,:entry_number=>'12345')
      e2 = Factory(:entry,:entry_number=>'65432')
      results = ActiveRecord::Base.connection.execute "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      # Start at row 5 just to make sure the return value is actually giving us the # of rows written and not the ending line number
      expect(@helper.new.write_result_set_to_sheet results, @sheet, ["EN", "IDENT"], 5).to eq 2

      @sheet.row(5).should == ['12345',e1.id]
      @sheet.row(6).should == ['65432',e2.id]
    end

    it "should handle timezone conversion for datetime columns" do
      release_date = 0.seconds.ago
      e1 = Factory(:entry,:entry_number=>'12345', :release_date => release_date)
      results = ActiveRecord::Base.connection.execute "SELECT release_date 'REL1', date(release_date) as 'Rel2' FROM entries order by entry_number ASC"
      Time.use_zone("Hawaii") do
        @helper.new.write_result_set_to_sheet results, @sheet, ["EN", "IDENT"], 0
      end

      @sheet.row(0)[0].to_s.should == release_date.in_time_zone("Hawaii").to_s
      @sheet.row(0)[1].to_s.should == release_date.strftime("%Y-%m-%d")
    end

    it "should convert nil to blank string in excel output" do
      @helper.new.write_result_set_to_sheet [[nil]], @sheet, ["EN"], 0
      @sheet.row(0).should == ['']
    end

    it "should use conversion lambdas to format output" do
      conversions = {}
      conversions['Col1'] = lambda {|row, val| 
        row.should == ['A', 'B', 'C']
        val.should == "A"
        "Col1"
      }
      conversions[1] = lambda{|row, val| 
        row.should == ['A', 'B', 'C']
        val.should == "B"
        "Col2"
      }
      conversions[:col_3] = lambda{|row, val| 
        row.should == ['A', 'B', 'C']
        val.should == "C"
        "Col3"
      }
      # Add a lambda by name and symbol for the 3rd column, proves name/symbol takes precedence
      conversions[2] = lambda{|row, val| 
        raise "Shouldn't use this conversion."
      }
      
      @helper.new.write_result_set_to_sheet [['A', 'B', 'C']], @sheet, ['Col1', 'Whatever', 'col_3'], 0, conversions
      @sheet.row(0).should == ['Col1', 'Col2', 'Col3']
    end
  end

  context :datetime_translation_lambda do
    it "should create a lambda that will translate a datetime value into the specified timezone" do
      conversion = @helper.new.datetime_translation_lambda "Hawaii", false

      now = Time.zone.now.in_time_zone "UTC"

      translated = conversion.call nil, now
      # Make sure the translated value is using the specified time zone (by comparing offset values)
      translated.utc_offset.should == ActiveSupport::TimeZone["Hawaii"].utc_offset
      translated.in_time_zone("UTC").should == now
    end

    it "should return a date if specified" do
      conversion = @helper.new.datetime_translation_lambda "Hawaii", true

      # Use a time we know is going to be one date in UTC and a day earlier in HST.
      now = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 01:00:00"

      translated = conversion.call nil, now
      translated.is_a?(Date).should be_true
      translated.to_s.should == "2012-12-31"
    end

    it "should handle nil times" do
      conversion = @helper.new.datetime_translation_lambda "Hawaii", false
      conversion.call(nil, nil).should be_nil
    end
  end

  describe "weblink_translation_lamda" do
    it "creates a lambda capable of transating an Id value to a URL" do
      ms = double("MasterSetup")
      ms.stub(:request_host).and_return "localhost"
      MasterSetup.stub(:get).and_return ms
      l = @helper.new.weblink_translation_lambda CoreModule::PRODUCT
      expect(l.call(nil, 1)).to eq Spreadsheet::Link.new(Product.excel_url(1), "Web View")
    end
  end

  describe "csv_translation_lambda" do
    it "csv's a string" do
      l = @helper.new.csv_translation_lambda
      expect(l.call(nil, "A\nB\n C")).to eq "A, B, C"
    end
    it "uses given parameters to split / joining" do 
      l = @helper.new.csv_translation_lambda "\n", ","
      expect(l.call(nil, "A,B,C")).to eq "A\nB\nC"
    end
    it "handles nil / blank values" do
      l = @helper.new.csv_translation_lambda
      expect(l.call(nil, nil)).to eq nil
      expect(l.call(nil, "   ")).to eq "   "
    end
  end

  context :sanitize_date_string do
    it "should return a date string" do
      s = @helper.new.sanitize_date_string "20130101"
      s.should == "2013-01-01"
    end

    it "should error on invalid strings" do
      expect{@helper.new.sanitize_date_string "notadate"}.to raise_error
    end

    it "should convert date to UTC date time string" do
      s = @helper.new.sanitize_date_string "20130101", "Hawaii"
      s.should == "2013-01-01 10:00:00"
    end

    it "should accept a date object" do
      s = @helper.new.sanitize_date_string Date.new(2013,1,1), "Hawaii"
      s.should == "2013-01-01 10:00:00"
    end
  end

  describe "workbook_to_tempfile" do

    before :each do 
      @wb = XlsMaker.create_workbook "Name", ["Header"]
    end

    it "writes a workbook to a tempfile and yields the tempfile" do
      workbook = nil
      path = nil
      name = nil
      tempfile = nil
      @helper.new.workbook_to_tempfile(@wb, "prefix", file_name: "test.xls") do |tf|
        workbook = Spreadsheet.open tf
        name = tf.original_filename
        tempfile = tf
      end

      expect(workbook.worksheet(0).row(0)).to eq ["Header"]
      expect(tempfile.closed?).to be_true
      expect(name).to eq "test.xls"
    end

    it "writes workbook to tempfile returning tempfile" do
      tf = nil
      begin
        tf = @helper.new.workbook_to_tempfile(@wb, "prefix", file_name: "test.xls")
        expect(tf.original_filename).to eq "test.xls"
        workbook = Spreadsheet.open tf
        expect(workbook.worksheet(0).row(0)).to eq ["Header"]
      ensure
        tf.close! unless tf.closed?
      end
    end
  end

end
