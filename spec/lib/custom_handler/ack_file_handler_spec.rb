require 'spec_helper'

describe OpenChain::CustomHandler::AckFileHandler do


  before :each do
    @p = Factory(:product)
    @u = Factory(:user, email: "example@example.com", username: "testuser")
  end
  it "should update product sync record" do
    @p.sync_records.create!(:trading_partner=>'XYZ')
    described_class.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'XYZ', "testuser"
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
    described_class.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER', "testuser"
    @p.reload
    @p.should have(1).sync_records
    sr = @p.sync_records.first
    sr.trading_partner.should == 'XYZ'
    sr.confirmed_at.should be_nil
  end
  it "should call errors callback if there is an error" do
    t = described_class.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn', "testuser", "h,h,h\n#{@p.unique_identifier},201306191706,OK", "OTHER")
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER', "testuser"
  end
  it "should handle extra whitespace" do
    t = described_class.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn', "testuser", "h,h,h\n#{@p.unique_identifier},201306191706,\"OK\"        ","OTHER")
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,\"OK\"        ", 'fn', 'OTHER', "testuser"
  end

  describe "parse" do
    it "should parse a file" do
      @p.sync_records.create!(:trading_partner=>'XYZ')
      described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", :sync_code=>"XYZ", email_address: "example@example.com"}
      @p.reload
      @p.should have(1).sync_records
      sr = @p.sync_records.first
      sr.confirmation_file_name.should == 'file.csv'
    end

    it "should send an email to the user provided if there's an error while processing the file" do
      described_class.new.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: "chainio_admin"})

      OpenMailer.deliveries.last.to.first.should == "support@vandegriftinc.com"
      OpenMailer.deliveries.last.subject.should == "[VFI Track] Ack File Processing Error"
    end

    it "should error if key is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:sync_code=>"XYZ", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have an s3 :key hash key."
    end

    it "should error if sync_code is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have a :sync_code hash key."
    end

    it "should set username to chainio_admin if none is provided in the options hash" do
      OpenChain::CustomHandler::AckFileHandler.any_instance.should_receive(:process_product_ack_file).with("h,h,h\n#{@p.unique_identifier},201306191706,OK", "file.csv", "XYZ", "chainio_admin")
      described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", :sync_code=>"XYZ"}
    end
  end
end
