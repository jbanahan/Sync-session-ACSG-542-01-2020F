require 'spec_helper'

describe OpenChain::Report::MarcJacobsFreightBudget do
  before :each do 
    @u = Factory(:user)
    @good_entry = Factory(:entry,:release_date=>0.seconds.ago,:house_bills_of_lading=>'HBOL',
      :broker_invoice_total=>90,:total_duty=>80,:total_fees=>50,:master_bills_of_lading=>'MBOL',
      :importer=>Factory(:company,:alliance_customer_number=>"MARJAC"))
    Entry.any_instance.stub(:can_view?).and_return(true)
  end
  after :each do
    @tmp.unlink if @tmp
  end
  it "should reject if user cannot view an entry" do
    Entry.any_instance.stub(:can_view?).and_return(false)
    lambda {described_class.run_report @u}.should raise_error "You do not have permission to view the entries on this report." 
  end
  it "should default to current year if not set" do
    mr = mock('report')
    mr.stub(:run).and_return('x')
    described_class.should_receive(:new).with(@u,Time.now.year,5).and_return(mr)
    described_class.run_report(@u, 'month'=>5).should == 'x'
  end
  it "should default to current month if not set" do
    mr = mock('report')
    mr.stub(:run).and_return('x')
    described_class.should_receive(:new).with(@u,2010,Time.now.month).and_return(mr)
    described_class.run_report(@u, 'year'=>2010).should == 'x'
  end
  it "should filter on proper year / month parameters" do
    mr = mock('report')
    mr.stub(:run).and_return('x')
    described_class.should_receive(:new).with(@u,2010,5).and_return(mr)
    described_class.run_report(@u, 'year'=>2010, 'month'=>5).should == 'x'
  end

  it "should write headings" do
    @tmp = described_class.run_report @u
    r = Spreadsheet.open(@tmp).worksheet(0).row(0)
    ["Broker","Month","HAWB","Brokerage Fee","Duty",
      "Total Fees","Master","Forwarder"].each_with_index do |h,i|
      r[i].should == h
    end
  end
  it "should write full row" do
    @good_entry.update_attributes(:release_date=>Date.new(2004,7,10))
    @tmp = described_class.run_report @u, 'year'=>2004, 'month'=>7
    r = Spreadsheet.open(@tmp).worksheet(0).row(1)
    ["Vandegrift","July","HBOL",90,80,50,"MBOL"].each_with_index do |v,i|
      r[i].should == v
    end
  end
  it "should include entries in given month" do
    @good_entry.update_attributes(:release_date=>Date.new(2004,7,10))
    @tmp = described_class.run_report @u, 'year'=>2004, 'month'=>7
    r = Spreadsheet.open(@tmp).worksheet(0).row(1)
    r[2].should == @good_entry.house_bills_of_lading
  end
  it "should not include entries outside of given month" do
    @good_entry.update_attributes(:release_date=>Date.new(2004,7,10))
    @tmp = described_class.run_report @u, 'year'=>2004, 'month'=>5
    r = Spreadsheet.open(@tmp).worksheet(0).row(1)
    r.size.should eq 0
  end

  it "should only include entries for customer MARJAC" do
    @good_entry.importer.update_attributes(:alliance_customer_number=>'NOTGOOD')
    @tmp = described_class.run_report @u
    r = Spreadsheet.open(@tmp).worksheet(0).row(1)
    r.size.should eq 0
  end

  it "should prorate charges using simple proration by HAWB count" do
    @good_entry.update_attributes(:house_bills_of_lading=>"1\n2")
    @tmp = described_class.run_report @u
    s = Spreadsheet.open(@tmp).worksheet(0)
    [["Vandegrift",Time.now.strftime("%B"),"1",45,40,25,"MBOL"],
    ["Vandegrift",Time.now.strftime("%B"),"2",45,40,25,"MBOL"]].each_with_index do |vs,rc|
      r = s.row(rc+1)
      vs.each_with_index {|v,i| r[i].should == v}
    end
  end
  it "should add/remove odd pennies on last prorated value" do
    @good_entry.update_attributes(:house_bills_of_lading=>"1\n2\n3")
    @tmp = described_class.run_report @u
    s = Spreadsheet.open(@tmp).worksheet(0)
    [["Vandegrift",Time.now.strftime("%B"),"1",30,26.67,16.67,"MBOL"],
    ["Vandegrift",Time.now.strftime("%B"),"2",30,26.67,16.67,"MBOL"],
    ["Vandegrift",Time.now.strftime("%B"),"3",30,26.66,16.66,"MBOL"]].each_with_index do |vs,rc|
      r = s.row(rc+1)
      vs.each_with_index {|v,i| r[i].should == v}
    end
  end
  
  it "should write row if no hbol" do
    @good_entry.update_attributes(:house_bills_of_lading=>nil)
    @tmp = described_class.run_report @u
    r = Spreadsheet.open(@tmp).worksheet(0).row(1)
    ["Vandegrift",Time.now.strftime("%B")," ",90,80,50,"MBOL"].each_with_index do |v,i|
      r[i].should == v
    end
  end
end
