require 'spec_helper'

describe OpenChain::CustomHandler::AckFileHandler do


  before :each do
    @p = Factory(:product)
  end
  it "should update product sync record" do
    @p.sync_records.create!(:trading_partner=>'XYZ')
    described_class.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'XYZ', "example@example.com", "some/key.txt"
    @p.reload
    @p.should have(1).sync_records
    sr = @p.sync_records.first
    sr.trading_partner.should == 'XYZ'
    sr.confirmed_at.should > 1.minute.ago
    sr.confirmation_file_name.should == 'fn'
    sr.failure_message.should be_blank
  end

  it "should not update sync record for another trading partner" do
    @tempfile = Tempfile.new ["key", ".txt"]
    @tempfile.binmode
    @tempfile << @s3_content
    @tempfile.rewind
    
    #mock s3 handling
    OpenChain::S3.should_receive(:download_to_tempfile).with("some","key.txt").and_yield(@tempfile)

    @p.sync_records.create!(:trading_partner=>'XYZ')
    described_class.new.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER', "example@example.com", "some/key.txt"
    @p.reload
    @p.should have(1).sync_records
    sr = @p.sync_records.first
    sr.trading_partner.should == 'XYZ'
    sr.confirmed_at.should be_nil

    @tempfile.close!
  end
  it "should call errors callback if there is an error" do
    t = described_class.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn', "example@example.com", "h,h,h\n#{@p.unique_identifier},201306191706,OK", "some/key.txt")
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER', "example@example.com", "some/key.txt"
  end
  it "should handle extra whitespace" do
    t = described_class.new
    msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
    t.should_receive(:handle_errors).with([msg],'fn', "example@example.com", "h,h,h\n#{@p.unique_identifier},201306191706,\"OK\"        ", "some/key.txt")
    t.process_product_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,\"OK\"        ", 'fn', 'OTHER', "example@example.com", "some/key.txt"
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

    it "should send an email to the email_address provided if there's an error while processing the file" do
      @tempfile = Tempfile.new ["fake-file", ".txt"]
      @tempfile.binmode
      @tempfile << @s3_content
      @tempfile.rewind
      
      #mock s3 handling
      OpenChain::S3.should_receive(:download_to_tempfile).with("fake-bucket","fake-file.txt").and_yield(@tempfile)

      described_class.new.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", email_address: "example@example.com"})

      OpenMailer.deliveries.last.to.first.should == "example@example.com"
      OpenMailer.deliveries.last.subject.should == "[VFI Track] Ack File Processing Error"

      @tempfile.close!
    end

    it "should error if key is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:sync_code=>"XYZ", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have an s3 :key hash key."
    end

    it "should error if sync_code is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have a :sync_code hash key."
    end

    it "should error if email_address is missing" do
      expect{described_class.new.parse "h,h,h\n#{@p.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", :sync_code=>"XYZ"}}.to raise_error ArgumentError, "Opts must have an :email_address hash key."
    end
  end
end
