require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler do
  it "should not report error for missing style if it's a related style" do
    cdefs = described_class.prep_custom_definitions [:related_styles]
    p = Factory(:product) 
    p.sync_records.create!(trading_partner:'XYZ')
    p.update_custom_value! cdefs[:related_styles], 'REL123'
    described_class.new.process_product_ack_file "h,h,h\nREL123,2013060191051,OK", 'fn.csv', 'XYZ', "chainio_admin"
    p.reload
    sr = p.sync_records.first
    sr.confirmed_at.should > 1.minute.ago
    sr.confirmation_file_name.should == 'fn.csv'
    sr.failure_message.should be_blank
  end
  it "should report real missing style" do
    h = described_class.new
    errors = h.get_ack_file_errors "h,h,h\nREL123,2013060191051,OK", 'fn.csv', 'XYZ'
    errors.should have(1).record
    errors.first.should == "Product REL123 confirmed, but it does not exist."
  end
end
