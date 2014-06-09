require 'spec_helper'
require 'open_chain/custom_handler/kewill_isf_manual_parser'

describe OpenChain::CustomHandler::KewillIsfManualParser do
  before :each do
    @u = Factory(:master_user)
    @k_nil = OpenChain::CustomHandler::KewillIsfManualParser.new(nil)
  end

  describe :can_view? do
    it "should be true when user can edit security filings" do
      User.any_instance.stub(:edit_security_filings?).and_return true
      @k_nil.can_view?(@u).should == true
    end

    it "should be false when user can't edit security filings" do
      User.any_instance.stub(:edit_security_filings?).and_return false
      @k_nil.can_view?(@u).should == false
    end
  end

  describe :process do
    it "should return nil and stop if the custom file is nil" do
      OpenChain::CustomHandler::KewillIsfManualParser.any_instance.should_not_receive(:process_s3)
      @k_nil.process(@u).should == nil
    end

    it "should return nil and stop if the custom file has nothing attached" do
      @cf = Factory(:attachment)
      Attachment.any_instance.stub(:attached).and_return nil
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      OpenChain::CustomHandler::KewillIsfManualParser.any_instance.should_not_receive(:process_s3)
      @k.process(@u).should == nil
    end

    it "should return nil and stop if the custom file attachment has no path" do
      @cf = Factory(:attachment)
      Paperclip::Attachment.any_instance.stub(:path).and_return nil
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      OpenChain::CustomHandler::KewillIsfManualParser.any_instance.should_not_receive(:process_s3)
      @k.process(@u).should == nil
    end

    it "should call process_s3 with the correct arguments given good input" do
      @cf = Factory(:attachment)
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      OpenChain::CustomHandler::KewillIsfManualParser.stub(:process_s3).and_return nil #don't bother faking a real s3 path
      OpenChain::CustomHandler::KewillIsfManualParser.should_receive(:process_s3).with(@cf.attached.path, "chain-io")
      @k.process(@u)
    end

    it "should create a message given good input" do
      @cf = Factory(:attachment)
      @k = OpenChain::CustomHandler::KewillIsfManualParser.new(@cf)
      @m = @u.messages
      @u.should_receive(:messages).and_return(@m)
      @m.should_receive(:create)
      OpenChain::CustomHandler::KewillIsfManualParser.stub(:process_s3).and_return nil
      @k.process(@u)
    end
  end

  describe :process_s3 do
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
      OpenChain::S3.stub(:download_to_tempfile).and_yield @t
    end

    it "should update the status of any matching security filings" do
      OpenChain::CustomHandler::KewillIsfManualParser.process_s3("doesn't matter","doesn't matter")
      @sf1.reload
      @sf2.reload
      @sf3.reload
      @sf1.status_code.should == "SOME STATUS 1"
      @sf2.status_code.should == "SOME STATUS 2"
      @sf3.status_code.should == "SOME STATUS 3"
    end

  end
end