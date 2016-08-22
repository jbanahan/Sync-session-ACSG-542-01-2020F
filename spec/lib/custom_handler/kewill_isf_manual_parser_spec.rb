require 'spec_helper'
require 'open_chain/custom_handler/kewill_isf_manual_parser'

describe OpenChain::CustomHandler::KewillIsfManualParser do
  before :each do
    @u = Factory(:master_user)
    @k_nil = OpenChain::CustomHandler::KewillIsfManualParser.new(nil)
  end

  describe "can_view?" do
    it "should be true when user can edit security filings" do
      allow_any_instance_of(User).to receive(:edit_security_filings?).and_return true
      expect(@k_nil.can_view?(@u)).to eq(true)
    end

    it "should be false when user can't edit security filings" do
      allow_any_instance_of(User).to receive(:edit_security_filings?).and_return false
      expect(@k_nil.can_view?(@u)).to eq(false)
    end
  end

  describe "process" do
    it "should return nil and stop if the custom file is nil" do
      expect_any_instance_of(OpenChain::CustomHandler::KewillIsfManualParser).not_to receive(:process_s3)
      expect(@k_nil.process(@u)).to eq(nil)
    end

    it "should return nil and stop if the custom file has nothing attached" do
      @cf = Factory(:attachment)
      allow_any_instance_of(Attachment).to receive(:attached).and_return nil
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      expect_any_instance_of(OpenChain::CustomHandler::KewillIsfManualParser).not_to receive(:process_s3)
      expect(@k.process(@u)).to eq(nil)
    end

    it "should return nil and stop if the custom file attachment has no path" do
      @cf = Factory(:attachment)
      allow_any_instance_of(Paperclip::Attachment).to receive(:path).and_return nil
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      expect_any_instance_of(OpenChain::CustomHandler::KewillIsfManualParser).not_to receive(:process_s3)
      expect(@k.process(@u)).to eq(nil)
    end

    it "should call process_s3 with the correct arguments given good input" do
      @cf = Factory(:attachment)
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      allow(OpenChain::CustomHandler::KewillIsfManualParser).to receive(:process_s3).and_return nil #don't bother faking a real s3 path
      expect(OpenChain::CustomHandler::KewillIsfManualParser).to receive(:process_s3).with(@cf.attached.path, OpenChain::S3.bucket_name(:production))
      @k.process(@u)
    end

    it "should create a message given good input" do
      @cf = Factory(:attachment)
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      @m = @u.messages
      expect(@u).to receive(:messages).and_return(@m)
      expect(@m).to receive(:create)
      allow(OpenChain::CustomHandler::KewillIsfManualParser).to receive(:process_s3).and_return nil
      @k.process(@u)
    end
  end

  describe "process_s3" do
    before :each do
      @sf1 = Factory(:security_filing, host_system_file_number: 11111, status_code: "Some default status")
      @sf2 = Factory(:security_filing, host_system_file_number: 22222, status_code: "Some default status")
      @sf3 = Factory(:security_filing, host_system_file_number: 33333, status_code: "Some default status")
      @t = Tempfile.new("kewill")
      @t << "ISF Importer,Logged,Status,Action Reason,SCAC Master,Master Bill,SCAC House,House Bill,ISF No.,Broker File No.,CBP Trans. No.,Loading Date,Booking No.,P.O. No.,Carrier,Vessel Name,Voyage,IE/TE,Loading,Unloading,Delivery,Sailing Date,Arrival Date,Container,Seller,Buyer,Manufacturer,Ship To,Create Subscriber,Modify Subscriber,Owner Subscriber,Create User,Modify User\r\n"
      @t << "PVH,3-Jun-14,SOME STATUS 1,Compliant Transaction,COSU,HB23752500T,COSU,TSZX1318447T,11111,,,,,,COSU,,,N,,,,,,KKFU6700083,,,,,VAND0323,VAND0323,VAND0323,HANDS_FREE,DBRIGHT\r\n"
      @t << "PVH,3-Jun-14,SOME STATUS 2,Compliant Transaction,COSU,HB23752500T,COSU,TSZX1318447T,22222,,,,,,COSU,,,N,,,,,,KKFU6700083,,,,,VAND0323,VAND0323,VAND0323,HANDS_FREE,DBRIGHT\r\n"
      @t << "PVH,3-Jun-14,SOME STATUS 3,Compliant Transaction,COSU,HB23752500T,COSU,TSZX1318447T,33333,,,,,,COSU,,,N,,,,,,KKFU6700083,,,,,VAND0323,VAND0323,VAND0323,HANDS_FREE,DBRIGHT"
      @t.rewind
      allow(OpenChain::S3).to receive(:download_to_tempfile).and_yield @t
    end

    it "should update the status of any matching security filings" do
      OpenChain::CustomHandler::KewillIsfManualParser.process_s3("doesn't matter","doesn't matter")
      @sf1.reload
      @sf2.reload
      @sf3.reload
      expect(@sf1.status_code).to eq("SOME STATUS 1")
      expect(@sf2.status_code).to eq("SOME STATUS 2")
      expect(@sf3.status_code).to eq("SOME STATUS 3")
    end

  end
end