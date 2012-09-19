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
    end
    it "should set finish_at" do
      d = DrawbackUploadFile.create!(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      OpenChain::UnderArmourExportParser.should_receive(:parse_csv_file).with('tmppath').and_return('abc')
      d.process @user
      d.reload
      d.finish_at.should > 2.seconds.ago
    end
    it "should write system message when processing is complete" do
      d = DrawbackUploadFile.create!(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      OpenChain::UnderArmourExportParser.should_receive(:parse_csv_file).with('tmppath').and_return('abc')
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
    it "should route UA_WM_IMPORTS" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = mock("S3 Attachment")
      s3_att.stub(:path).and_return('xyz')
      @mock_attachment.stub(:attached).and_return(s3_att)
      OpenChain::UnderArmourReceivingParser.should_receive(:parse_s3).with('xyz').and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route OHL Entry files" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_OHL_ENTRY)
      OpenChain::OhlDrawbackParser.should_receive(:parse).with('tmppath').and_return('abc')
      OpenChain::UnderArmourDrawbackProcessor.should_receive(:process_entries).with('abc').and_return('def')
      d.process(@user).should == 'def'
    end
    it "should route DDB Export file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      OpenChain::UnderArmourExportParser.should_receive(:parse_csv_file).with('tmppath').and_return('abc')
      d.process(@user).should == 'abc'
    end
    it "should route FMI Export file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_FMI_EXPORTS)
      OpenChain::UnderArmourExportParser.should_receive(:parse_fmi_csv_file).with('tmppath').and_return('abc')
      d.process(@user).should == 'abc'
    end
  end
end
