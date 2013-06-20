require 'spec_helper'

describe "OpenChain::CustomHandler::AckFileHandler" do


  before :each do
    @p = Factory(:product)
    @tc = Class.new do 
      include OpenChain::CustomHandler::AckFileHandler  
    end
  end
  it "should update product sync record" do
    @p.sync_records.create!(:trading_partner=>'XYZ')
    @tc.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'XYZ'
    @p.reload
    @p.should have(1).sync_records
    sr = @p.sync_records.first
    sr.trading_partner.should == 'XYZ'
    sr.confirmed_at.should > 1.minute.ago
    sr.confirmation_file_name.should == 'fn'
    sr.failure_message.should be_blank
  end

  it "should not update sync record for another trading partner" do
    @p.sync_records.create!(:trading_partner=>'XYZ')
    @tc.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER'
    @p.reload
    @p.should have(1).sync_records
    sr = @p.sync_records.first
    sr.trading_partner.should == 'XYZ'
    sr.confirmed_at.should be_nil
  end
  it "should call errors callback if there is an error" do
    t = @tc.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn')
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER'
  end
end
