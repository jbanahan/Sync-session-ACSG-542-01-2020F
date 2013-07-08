require 'spec_helper'

describe OpenChain::Report::XLSSearch do
  before :each do
    @u = Factory(:user)
    @xl_out = mock("Spreadsheet")
    @xl_out.stub(:write)
    @xl_maker = mock("XlsMaker")
    @xl_maker.should_receive(:make_from_search_query_by_search_id_and_user_id).and_return(@xl_out)
  end
  it "should include links" do
    ss = Factory(:search_setup,:include_links=>true,:user=>@u)
    XlsMaker.should_receive(:new).with({:include_links=>true,:no_time=>false}).and_return(@xl_maker)  
    described_class.run_report @u, {'search_setup_id'=>ss.id}
  end
  it "should include 'no time' flag" do
    ss = Factory(:search_setup,:no_time=>true,:user=>@u)
    XlsMaker.should_receive(:new).with({:include_links=>false,:no_time=>true}).and_return(@xl_maker)  
    described_class.run_report @u, {'search_setup_id'=>ss.id}
  end
end
