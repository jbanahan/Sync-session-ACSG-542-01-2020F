describe DrawbackUploadFile do
  describe "process" do
    let!(:user) { FactoryBot(:user) }
    let(:temp) { instance_double("tempfile") }
    let(:mock_attachment) { instance_double("Attachment") }
    let!(:importer) { FactoryBot(:company, importer: true) }

    before do
      allow(temp).to receive(:path).and_return('tmppath')
      allow_any_instance_of(described_class).to receive(:tempfile).and_return(temp)
      allow(mock_attachment).to receive(:attached_file_name).and_return("x")
      allow_any_instance_of(described_class).to receive(:attachment).and_return(mock_attachment)
    end

    it "sets finish_at" do
      importer.update! master: true
      d = described_class.create!(processor: DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_csv_file).with('tmppath', importer).and_return('abc')
      d.process user
      d.reload
      expect(d.finish_at).to be > 2.seconds.ago
    end

    it "writes system message when processing is complete" do
      importer.update! master: true
      d = described_class.create!(processor: DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_csv_file).with('tmppath', importer).and_return('abc')
      d.process user
      user.reload
      expect(user.messages.size).to eq(1)
    end

    it "errors if processor not set" do
      expect {described_class.new.process(user)}.to raise_error(/Processor/)
    end

    it "errors if processor not valid" do
      expect {described_class.new(processor: 'bad').process(user)}.to raise_error(/Processor/)
    end

    it "catches and log errors from delegated processes" do
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = instance_double("S3 Attachment")
      allow(s3_att).to receive(:path).and_return('xyz')
      allow(mock_attachment).to receive(:attached).and_return(s3_att)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser).to receive(:parse_s3).with('xyz').and_raise("ERR")
      expect do
        expect(d.process(user)).to eq(nil)
      end.to change(ErrorLogEntry, :count).by(1)
      expect(d.finish_at).to be > 10.seconds.ago
      expect(d.error_message).to eq("ERR")
    end

    it "routes UA_WM_IMPORTS" do
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_UA_WM_IMPORTS)
      s3_att = instance_double("S3 Attachment")
      allow(s3_att).to receive(:path).and_return('xyz')
      allow(mock_attachment).to receive(:attached).and_return(s3_att)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser).to receive(:parse_s3).with('xyz').and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it "routes OHL Entry files" do
      expect(Entry).to receive(:where).with("arrival_date > ?", instance_of(ActiveSupport::TimeWithZone)).and_return('abc')
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_OHL_ENTRY)
      expect(OpenChain::OhlDrawbackParser).to receive(:parse).with('tmppath')
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourDrawbackProcessor).to receive(:process_entries).with('abc').and_return('def')
      expect(d.process(user)).to eq('def')
    end

    it "routes DDB Export file" do
      importer.update! master: true
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_UA_DDB_EXPORTS)
      FactoryBot(:company, importer: true)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_csv_file).with('tmppath', importer).and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it "routes FMI Export file" do
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_UA_FMI_EXPORTS)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser).to receive(:parse_fmi_csv_file).with('tmppath').and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it "routes J Crew Import V2 files" do
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_JCREW_IMPORT_V2)
      expect(OpenChain::CustomHandler::JCrew::JCrewDrawbackImportProcessorV2).to receive(:parse_csv_file).with('tmppath', user).and_return('abc')
      expect(d.process(user)).to eq 'abc'
    end

    it "routes J Crew Canada Export file" do
      imp = with_customs_management_id(FactoryBot(:importer), "JCREW")
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_JCREW_CANADA_EXPORTS)
      expect(OpenChain::CustomHandler::JCrew::JCrewDrawbackExportParser).to receive(:parse_csv_file).with('tmppath', imp).and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it 'routes J Crew Borderfree Export file' do
      imp = with_customs_management_id(FactoryBot(:importer), "JCREW")
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_JCREW_BORDERFREE)
      expect(OpenChain::CustomHandler::JCrew::JCrewBorderfreeDrawbackExportParser).to receive(:parse_csv_file).with('tmppath', imp).and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it "routes Lands End Export file" do
      imp = with_customs_management_id(FactoryBot(:importer), "LANDS")
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_LANDS_END_EXPORTS)
      expect(OpenChain::LandsEndExportParser).to receive(:parse_csv_file).with('tmppath', imp).and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it "routes Crocs Export file" do
      imp = with_customs_management_id(FactoryBot(:importer), "CROCS")
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_CROCS_EXPORTS)
      expect(OpenChain::CustomHandler::Crocs::CrocsDrawbackExportParser).to receive(:parse_csv_file).with('tmppath', imp).and_return('abc')
      expect(d.process(user)).to eq('abc')
    end

    it "routes Crocs Receiving file" do
      with_customs_management_id(FactoryBot(:importer), "CROCS")
      d = described_class.new(processor: DrawbackUploadFile::PROCESSOR_CROCS_RECEIVING)
      s3_att = instance_double("S3 Attachment")
      allow(s3_att).to receive(:path).and_return('xyz')
      allow(mock_attachment).to receive(:attached).and_return(s3_att)
      expect(OpenChain::CustomHandler::Crocs::CrocsReceivingParser).to receive(:parse_s3).with('xyz').and_return([Date.new(2011, 1, 1), Date.new(2012, 1, 1)])

      expect(OpenChain::CustomHandler::Crocs::CrocsDrawbackProcessor).to receive(:process_entries_by_arrival_date)
        .with(Date.new(2011, 1, 1), Date.new(2012, 1, 1)).and_return 'abc'

      expect(d.process(user)).to eq('abc')
    end
  end
end
