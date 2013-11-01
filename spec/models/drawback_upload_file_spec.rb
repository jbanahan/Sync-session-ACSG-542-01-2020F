require 'spec_helper'

describe DrawbackUploadFile do
  describe :process do
    before :each do
      @tmp = mock("Tempfile")
      @tmp.stub(:path).and_return('tmppath')
      DrawbackUploadFile.any_instance.stub(:tempfile).and_return(@tmp)
      @user = Factory(:user)
      @mock_attachment = mock("Attachment")
      @mock_attachment.stub(:attached_file_name).and_return("x")
      DrawbackUploadFile.any_instance.stub(:attachment).and_return(@mock_attachment) 
      @importer = Factory(:company,:importer=>true)
    end
    it "should set finish_at" do
      d = DrawbackUploadFile.create!(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser.should_receive(:parse_csv_file).with('tmppath',@importer).and_return('abc')
      d.process @user
      d.reload
      d.finish_at.should > 2.seconds.ago
    end
    it "should write system message when processing is complete" do
      d = DrawbackUploadFile.create!(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser.should_receive(:parse_csv_file).with('tmppath',@importer).and_return('abc')
      d.process @user
      @user.reload
      @user.should have(1).messages
    end
    it "should error if processor not set" do
      lambda {DrawbackUploadFile.new.process(@user)}.should raise_error
    end
    it "should error if processor not valid" do
      lambda {DrawbackUploadFile.new(:processor=>'bad').process(@user)}.should raise_error
    end
    it "should catch and log errors from delegated processes" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = mock("S3 Attachment")
      s3_att.stub(:path).and_return('xyz')
      @mock_attachment.stub(:attached).and_return(s3_att)
      RuntimeError.any_instance.should_receive(:log_me)
      OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser.should_receive(:parse_s3).with('xyz').and_raise("ERR")
      d.process(@user).should == nil
      d.finish_at.should > 10.seconds.ago
      d.error_message.should == "ERR"
    end
    it "should route UA_WM_IMPORTS" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = mock("S3 Attachment")
      s3_att.stub(:path).and_return('xyz')
      @mock_attachment.stub(:attached).and_return(s3_att)
      OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser.should_receive(:parse_s3).with('xyz').and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route OHL Entry files" do
      Entry.should_receive(:where).with("arrival_date > ?",instance_of(ActiveSupport::TimeWithZone)).and_return('abc')
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_OHL_ENTRY)
      OpenChain::OhlDrawbackParser.should_receive(:parse).with('tmppath')
      OpenChain::CustomHandler::UnderArmour::UnderArmourDrawbackProcessor.should_receive(:process_entries).with('abc').and_return('def')
      d.process(@user).should == 'def'
    end
    it "should route DDB Export file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      imp = Factory(:company,:importer=>true)
      OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser.should_receive(:parse_csv_file).with('tmppath',Company.find_by_importer(true)).and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route FMI Export file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_FMI_EXPORTS)
      OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser.should_receive(:parse_fmi_csv_file).with('tmppath').and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route J Crew shipment file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_JCREW_SHIPMENTS)
      OpenChain::CustomHandler::JCrewShipmentParser.should_receive(:parse_merged_entry_file).with('tmppath').and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route Lands End Export file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"LANDS")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_LANDS_END_EXPORTS)
      OpenChain::LandsEndExportParser.should_receive(:parse_csv_file).with('tmppath',imp).and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route Crocs Export file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"CROCS")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_CROCS_EXPORTS)
      OpenChain::CustomHandler::Crocs::CrocsDrawbackExportParser.should_receive(:parse_csv_file).with('tmppath',imp).and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route Crocs Receiving file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"CROCS")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_CROCS_RECEIVING)
      s3_att = mock("S3 Attachment")
      s3_att.stub(:path).and_return('xyz')
      @mock_attachment.stub(:attached).and_return(s3_att)
      OpenChain::CustomHandler::Crocs::CrocsReceivingParser.should_receive(:parse_s3).with('xyz').and_return('abc')
      d.process(@user).should == 'abc'
    end
  end
end
