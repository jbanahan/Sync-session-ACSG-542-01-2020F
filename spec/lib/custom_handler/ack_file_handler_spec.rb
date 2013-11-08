require 'spec_helper'

describe OpenChain::CustomHandler::AckFileHandler do


  before :each do
    @p = Factory(:product)
  end
  it "should update product sync record" do
    @p.sync_records.create!(:trading_partner=>'XYZ')
    described_class.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'XYZ'
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
    described_class.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER'
    @p.reload
    @p.should have(1).sync_records
    sr = @p.sync_records.first
    sr.trading_partner.should == 'XYZ'
    sr.confirmed_at.should be_nil
  end
  it "should call errors callback if there is an error" do
    t = described_class.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn')
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER'
  end
  it "should handle extra whitespace" do
    t = described_class.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn')
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,\"OK\"        ", 'fn', 'OTHER'
  end

  describe "parse" do
    it "should parse a file" do
      @p.sync_records.create!(:trading_partner=>'XYZ')
      described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", :sync_code=>"XYZ"}
      @p.reload
      @p.should have(1).sync_records
      sr = @p.sync_records.first
      sr.confirmation_file_name.should == 'file.csv'
    end

    it "should error if key is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:sync_code=>"XYZ"}}.to raise_error ArgumentError, "Opts must have an s3 :key hash key."
    end

    it "should error if sync_code is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv",}}.to raise_error ArgumentError, "Opts must have a :sync_code hash key."
    end
  end
end
