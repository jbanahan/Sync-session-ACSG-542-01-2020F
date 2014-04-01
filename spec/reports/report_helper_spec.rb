require 'spec_helper'

describe OpenChain::Report::ReportHelper do

  before :each do 
    @helper = Class.new do
        include OpenChain::Report::ReportHelper

        def run query, conversions = {}
          wb = Spreadsheet::Workbook.new
          s = wb.create_worksheet :name=>'x'
          table_from_query s, query, conversions
          wb
        end
      end
  end
  
  describe "table_from_query" do
    it "should build sheet from query" do
      e1 = Factory(:entry,:entry_number=>'12345')
      e2 = Factory(:entry,:entry_number=>'65432')
      q = "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      workbook = @helper.new.run q
      sheet = workbook.worksheet 0
      sheet.row(0).should == ['EN','IDENT']
      sheet.row(1).should == ['12345',e1.id]
      sheet.row(2).should == ['65432',e2.id]
    end

    it "should handle timezone conversion for datetime columns" do
      release_date = 0.seconds.ago
      e1 = Factory(:entry,:entry_number=>'12345', :release_date => release_date)
      q = "SELECT release_date 'REL1', date(release_date) as 'Rel2' FROM entries order by entry_number ASC"
      workbook = nil
      Time.use_zone("Hawaii") do
        workbook = @helper.new.run q
      end

      sheet = workbook.worksheet 0
      sheet.row(0).should == ['REL1', 'Rel2']
      sheet.row(1)[0].to_s.should == release_date.in_time_zone("Hawaii").to_s
      sheet.row(1)[1].to_s.should == release_date.strftime("%Y-%m-%d")
    end

    it "should convert nil to blank string in excel output" do
      workbook = @helper.new.run "SELECT null as 'Test'"
      sheet = workbook.worksheet 0
      sheet.row(0).should == ['Test']
      sheet.row(1).should == ['']
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
      

      workbook = @helper.new.run "SELECT 'A' as 'Col1', 'B' as 'Whatever', 'C' as 'col_3' ", conversions
      sheet = workbook.worksheet 0
      sheet.row(0).should == ['Col1', 'Whatever', 'col_3']
      sheet.row(1).should == ['Col1', 'Col2', 'Col3']
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

  context :write_val do
    it "should take a format value and utilize it" do
      wb = Spreadsheet::Workbook.new
      s = wb.create_worksheet :name=>'x'
      row = s.row 0

      # Use datetime value so we're sure that the passed in format overrides any default ones
      @helper.new.write_val s, row, 0, 0, Time.zone.now, :format => Spreadsheet::Format.new(:number_format=>'MM/DD/YYYY')
      row.format(0).number_format.should == "MM/DD/YYYY"
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

end
