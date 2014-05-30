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
    it "runs a query, adds headers to sheet, passing control to write result sheet" do
      q = "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      h = @helper.new
      # We can't really reliably determine result set, since there is no ActiveRecord base for it
      # so just detect it as something that responds to each, since that's how the method handles it anyway.
      h.should_receive(:write_result_set_to_sheet).with(duck_type(:each), instance_of(Spreadsheet::Worksheet), ['EN','IDENT'], 1, {})
      h.run q
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
      @helper.new.write_result_set_to_sheet results, @sheet, ["EN", "IDENT"], 0

      @sheet.row(0).should == ['12345',e1.id]
      @sheet.row(1).should == ['65432',e2.id]
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
