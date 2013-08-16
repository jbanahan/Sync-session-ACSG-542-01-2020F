require 'spec_helper'
require 'spreadsheet'

describe OpenChain::Report::LandedCostReport do

  context :run do
    before :each do 
      @user = Factory :master_user
      @entry1 = Factory(:entry, :customer_number=>"CUST", :release_date=>(Time.zone.now - 1.day), :entry_number=>"1", :transport_mode_code=>"2", :customer_references=>"3\n4")
      @entry2 = Factory(:entry, :customer_number=>"CUST", :release_date=>Time.zone.now, :entry_number=>"5", :transport_mode_code=>"6", :customer_references=>"7\n8")
    end

    after :each do
      @tempfile.close! if @tempfile && !@tempfile.closed?
    end

    # All the underlying logic for getting the report values is 
    # handled by the landed cost data generator and is tested in its spec.
    # So just make sure we're calling that and handling the appropriate values
    # coming back out of there.
    it "should run a landed cost report" do
      start_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
      c = described_class.new @user, :customer_number=>"CUST", :start_date => start_date, :end_date => end_date
      OpenChain::Report::LandedCostDataGenerator.any_instance.should_receive(:landed_cost_data_for_entry).with(@entry1.id).and_return(generator_data(@entry1))
      OpenChain::Report::LandedCostDataGenerator.any_instance.should_receive(:landed_cost_data_for_entry).with(@entry2.id).and_return(generator_data(@entry2))

      @tempfile = c.run

      File.basename(@tempfile).should match /^Landed Cost CUST/

      sheet = Spreadsheet.open(@tempfile.path).worksheet "CUST #{start_date} - #{end_date}"

      # don't really care about the header names
      sheet.row(1)[0].should == @entry1.broker_reference
      sheet.row(1)[1].should == @entry1.entry_number
      sheet.row(1)[2].strftime("%Y-%m-%d").should == @entry1.release_date.strftime("%Y-%m-%d")
      sheet.row(1)[3].should == @entry1.transport_mode_code
      sheet.row(1)[4].should == @entry1.customer_references.split("\n").join(", ")
      # This info is all hardcoded in the generator_data method
      sheet.row(1)[5].should == "1234.56.7890, 9876.54.3210"
      sheet.row(1)[6].should == "PO"
      sheet.row(1)[7].should == 1
      sheet.row(1)[8].should == BigDecimal.new("1")
      sheet.row(1)[9].should == BigDecimal.new("2")
      sheet.row(1)[10].should == BigDecimal.new("3")
      sheet.row(1)[11].should == BigDecimal.new("4")
      sheet.row(1)[12].should == BigDecimal.new("5")
      sheet.row(1)[13].should == BigDecimal.new("6")
      sheet.row(1)[14].should == BigDecimal.new("7")
      sheet.row(1)[15].should == BigDecimal.new("8")
      sheet.row(1)[16].should == BigDecimal.new("9")
      sheet.row(1)[17].should == BigDecimal.new("10.99") # landed cost is rounded to 2 decimal places

      # Just make sure the second entry's row is there
      sheet.row(2)[0].should == @entry2.broker_reference

    end

    def generator_data entry
      {:entries=>[{:broker_reference=>entry.broker_reference, :entry_number=>entry.entry_number, :release_date=>entry.release_date,
        :transport_mode_code=>entry.transport_mode_code, :customer_reference=>entry.customer_references.split("\n"),
        :commercial_invoices=>[
          {:commercial_invoice_lines=>[
            :hts_code =>["1234567890", "9876543210"], :po_number=>"PO", :quantity => 1, :entered_value=>BigDecimal.new("1"),
            :brokerage=>BigDecimal.new("2"), :other=>BigDecimal.new("3"), :international_freight=>BigDecimal.new("4"),
            :hmf=>BigDecimal.new("5"), :mpf=>BigDecimal.new("6"), :cotton_fee=>BigDecimal.new("7"), :duty=>BigDecimal.new("8"),
            :landed_cost=>BigDecimal.new("9"), :per_unit=>{:landed_cost=>BigDecimal.new("10.987")}
            ]}
          ]
      }]}
    end

    it "should not find an entry for different customer" do
      start_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
      c = described_class.new @user, :customer_number=>"DIFFERENT", :start_date => start_date, :end_date => end_date
      @tempfile = c.run

      sheet = Spreadsheet.open(@tempfile.path).worksheet 0
      sheet.row(1)[0].should be_nil
    end

    it "should not find an entry outside date range" do
      start_date = (Time.zone.now - 3.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      c = described_class.new @user, :customer_number=>"CUST", :start_date => start_date, :end_date => end_date
      @tempfile = c.run

      sheet = Spreadsheet.open(@tempfile.path).worksheet 0
      sheet.row(1)[0].should be_nil
    end

    it "should not find entries a user can't view" do
      # We didn't set importer_id in the entries, so none should match
      user = Factory(:importer_user)

      start_date = (Time.zone.now - 2.days).strftime("%Y-%m-%d")
      end_date = (Time.zone.now + 1.day).strftime("%Y-%m-%d")
      c = described_class.new user, :customer_number=>"CUST", :start_date => start_date, :end_date => end_date
      @tempfile = c.run

      sheet = Spreadsheet.open(@tempfile.path).worksheet 0
      sheet.row(1)[0].should be_nil
    end
  end
end