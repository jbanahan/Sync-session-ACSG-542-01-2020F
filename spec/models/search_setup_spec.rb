require 'spec_helper'

describe SearchSetup do
  describe "uploadable?" do
    #there are quite a few tests for this in the old test unit structure
    it 'should always reject ENTRY' do
      ss = Factory(:search_setup,:module_type=>'Entry')
      msgs = []
      ss.uploadable?(msgs).should be_false
      msgs.should have(1).item
      msgs.first.should == "Upload functionality is not available for Entries."
    end
    it 'should always reject BROKER_INVOICE' do
      ss = Factory(:search_setup,:module_type=>'BrokerInvoice')
      msgs = []
      ss.uploadable?(msgs).should be_false
      msgs.should have(1).item
      msgs.first.should == "Upload functionality is not available for Invoices."
    end
  end
end
