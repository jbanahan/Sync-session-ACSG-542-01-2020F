require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler do
  it "should not report error for missing style if it's a related style" do
    cdefs = described_class.prep_custom_definitions [:related_styles]
    p = Factory(:product) 
    p.sync_records.create!(trading_partner:'XYZ')
    p.update_custom_value! cdefs[:related_styles], 'REL123'
    described_class.new.process_ack_file "h,h,h\nREL123,2013060191051,OK", 'fn.csv', 'XYZ', "chainio_admin"
    p.reload
    sr = p.sync_records.first
    expect(sr.confirmed_at).to be > 1.minute.ago
    expect(sr.confirmation_file_name).to eq('fn.csv')
    expect(sr.failure_message).to be_blank
  end
  it "should report real missing style" do
    h = described_class.new
    errors = h.get_ack_file_errors "h,h,h\nREL123,2013060191051,OK", 'fn.csv', 'XYZ'
    expect(errors.size).to eq(1)
    expect(errors.first).to eq("Product REL123 confirmed, but it does not exist.")
  end
end
