require 'spec_helper'
require 'open_chain/tariff_finder'
require 'open_chain/xl_client'

describe PartNumberCorrelation do
  describe :process do
    before :each do
      @user = Factory(:user)
      @pnc = Factory(:part_number_correlation, starting_row: 1, part_column: "B",
              part_regex: "", entry_country_iso: "US", user: @user)
      @pnc.attachment = Factory(:attachment, attached_file_name: "sheet.xls", attached_content_type: "application/vnd.ms-excel")
      @usa = Factory(:country)
    end

    it "should update xls files with three additional columns" do
      tf = OpenChain::TariffFinder.new(@usa, [])
      OpenChain::TariffFinder.should_receive(:new).and_return(tf)
      OpenChain::XLClient.any_instance.should_receive(:get_row).and_return([1,2,3,4])
      OpenChain::XLClient.any_instance.should_receive(:all_row_values).and_yield(["UID","1234-XLS-AB12","OK","ABC"])
      OpenChain::XLClient.any_instance.should_receive(:get_cell).and_return("1234-XLS-AB12")

      s = Struct.new(:part_number,:country_origin_code,:mid,:hts_code)
      r = s.new("1234-XLS-AB12","US","MFID","12345")

      OpenChain::TariffFinder.any_instance.should_receive(:find_by_style).with("1234-XLS-AB12").and_return(r)

      # 3 times for the headers, 3 times for the extra cells
      OpenChain::XLClient.any_instance.should_receive(:set_cell).exactly(6).times
      OpenChain::XLClient.any_instance.should_receive(:save)

      @pnc.should_receive(:finished_time=)
      @pnc.should_receive(:save!)
      
      @pnc.process([1, 2])

      @user.messages.length.should == 1
      @user.messages.last.subject.should == "Part Number Correlation Report Finished"
    end

    it "should send an error message on exception" do
      @pnc.process([1,2])
      @user.messages.length.should == 1
      @user.messages.last.subject.should == "ERROR: Part Number Correlation Report"
    end
  end

  describe :alphabet_column_to_numeric_column do
    it "should return the correct values for Excel column headings" do
      @pnc = PartNumberCorrelation.new
      
      #note: indexed at 0
      @pnc.alphabet_column_to_numeric_column("A").should == 0
      @pnc.alphabet_column_to_numeric_column("Z").should == 25
      @pnc.alphabet_column_to_numeric_column("AA").should == 26
      @pnc.alphabet_column_to_numeric_column("AZ").should == 51
      @pnc.alphabet_column_to_numeric_column("ZZZ").should == (26 * (26**2)) + (26 * (26**1)) + 26 - 1
    end
  end
end