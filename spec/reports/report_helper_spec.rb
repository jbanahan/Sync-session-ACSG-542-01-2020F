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
      release_date = Time.now
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

end
