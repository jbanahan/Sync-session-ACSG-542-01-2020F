require 'spec_helper'

describe DrawbackUploadFile do
  describe :process do
    before :each do
      @tmp = double("Tempfile")
      allow(@tmp).to receive(:path).and_return('tmppath')
      allow_any_instance_of(DrawbackUploadFile).to receive(:tempfile).and_return(@tmp)
      @user = Factory(:user)
      @mock_attachment = double("Attachment")
      allow(@mock_attachment).to receive(:attached_file_name).and_return("x")
      allow_any_instance_of(DrawbackUploadFile).to receive(:attachment).and_return(@mock_attachment)
      @importer = Factory(:company,:importer=>true)
    end
    it "should set finish_at" do
      d = DrawbackUploadFile.create!(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_csv_file).with('tmppath',@importer).and_return('abc')
      d.process @user
      d.reload
      expect(d.finish_at).to be > 2.seconds.ago
    end
    it "should write system message when processing is complete" do
      d = DrawbackUploadFile.create!(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_csv_file).with('tmppath',@importer).and_return('abc')
      d.process @user
      @user.reload
      expect(@user.messages.size).to eq(1)
    end
    it "should error if processor not set" do
      expect {DrawbackUploadFile.new.process(@user)}.to raise_error
    end
    it "should error if processor not valid" do
      expect {DrawbackUploadFile.new(:processor=>'bad').process(@user)}.to raise_error
    end
    it "should catch and log errors from delegated processes" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = double("S3 Attachment")
      allow(s3_att).to receive(:path).and_return('xyz')
      allow(@mock_attachment).to receive(:attached).and_return(s3_att)
      expect_any_instance_of(RuntimeError).to receive(:log_me)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser).to receive(:parse_s3).with('xyz').and_raise("ERR")
      expect(d.process(@user)).to eq(nil)
      expect(d.finish_at).to be > 10.seconds.ago
      expect(d.error_message).to eq("ERR")
    end
    it "should route UA_WM_IMPORTS" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = double("S3 Attachment")
      allow(s3_att).to receive(:path).and_return('xyz')
      allow(@mock_attachment).to receive(:attached).and_return(s3_att)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser).to receive(:parse_s3).with('xyz').and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it "should route OHL Entry files" do
      expect(Entry).to receive(:where).with("arrival_date > ?",instance_of(ActiveSupport::TimeWithZone)).and_return('abc')
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_OHL_ENTRY)
      expect(OpenChain::OhlDrawbackParser).to receive(:parse).with('tmppath')
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourDrawbackProcessor).to receive(:process_entries).with('abc').and_return('def')
      expect(d.process(@user)).to eq('def')
    end
    it "should route DDB Export file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      imp = Factory(:company,:importer=>true)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_csv_file).with('tmppath',Company.find_by_importer(true)).and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it "should route FMI Export file" do
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_UA_FMI_EXPORTS)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_fmi_csv_file).with('tmppath').and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it "should route J Crew Import V2 files" do
      d = DrawbackUploadFile.new(processor:DrawbackUploadFile::PROCESSOR_JCREW_IMPORT_V2)
      expect(OpenChain::CustomHandler::JCrew::JCrewDrawbackImportProcessorV2).to receive(:parse_csv_file).with('tmppath',@user).and_return('abc')
      expect(d.process(@user)).to eq 'abc'
    end
    it "should route J Crew Canada Export file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"JCREW")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_JCREW_CANADA_EXPORTS)
      expect(OpenChain::CustomHandler::JCrew::JCrewDrawbackExportParser).to receive(:parse_csv_file).with('tmppath', imp).and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it 'should route J Crew Borderfree Export file' do
      imp = Factory(:company, importer: true, alliance_customer_number: "JCREW")
      d = DrawbackUploadFile.new(processor: DrawbackUploadFile::PROCESSOR_JCREW_BORDERFREE)
      expect(OpenChain::CustomHandler::JCrew::JCrewBorderfreeDrawbackExportParser).to receive(:parse_csv_file).with('tmppath', imp).and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it "should route Lands End Export file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"LANDS")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_LANDS_END_EXPORTS)
      expect(OpenChain::LandsEndExportParser).to receive(:parse_csv_file).with('tmppath',imp).and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it "should route Crocs Export file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"CROCS")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_CROCS_EXPORTS)
      expect(OpenChain::CustomHandler::Crocs::CrocsDrawbackExportParser).to receive(:parse_csv_file).with('tmppath',imp).and_return('abc')
      expect(d.process(@user)).to eq('abc')
    end
    it "should route Crocs Receiving file" do
      imp = Factory(:company,:importer=>true,:alliance_customer_number=>"CROCS")
      d = DrawbackUploadFile.new(:processor=>DrawbackUploadFile::PROCESSOR_CROCS_RECEIVING)
      s3_att = double("S3 Attachment")
      allow(s3_att).to receive(:path).and_return('xyz')
      allow(@mock_attachment).to receive(:attached).and_return(s3_att)
      expect(OpenChain::CustomHandler::Crocs::CrocsReceivingParser).to receive(:parse_s3).with('xyz').and_return([Date.new(2011,1,1),Date.new(2012,1,1)])
      expect(OpenChain::CustomHandler::Crocs::CrocsDrawbackProcessor).to receive(:process_entries_by_arrival_date).with(Date.new(2011,1,1),Date.new(2012,1,1)).and_return 'abc'
      expect(d.process(@user)).to eq('abc')
    end
  end
end
