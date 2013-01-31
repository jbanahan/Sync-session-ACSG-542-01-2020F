require 'spec_helper'

describe OpenChain::Report::ReportHelper do
  
  describe "table_from_query" do
    it "should build sheet from query" do
      k = Class.new do
        include OpenChain::Report::ReportHelper

        def run query
          wb = Spreadsheet::Workbook.new
          s = wb.create_worksheet :name=>'x'
          table_from_query s, query
          wb
        end
      end
      e1 = Factory(:entry,:entry_number=>'12345')
      e2 = Factory(:entry,:entry_number=>'65432')
      q = "SELECT entry_number as 'EN', id as 'IDENT' FROM entries order by entry_number ASC"
      workbook = k.new.run q
      sheet = workbook.worksheet 0
      sheet.row(0).should == ['EN','IDENT']
      sheet.row(1).should == ['12345',e1.id]
      sheet.row(2).should == ['65432',e2.id]
    end
  end

end
