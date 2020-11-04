describe OpenChain::IntegrationParserBroker do
  subject do
    Class.new do
      include OpenChain::IntegrationParserBroker
    end
  end

  describe "parse" do
    let (:parser) do
      Class.new do
        def parse _data, _opts; end
      end.new
    end

    let (:opts) { {bucket: "bucket", key: "key"} }
    let! (:inbound_file) do
      f = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return f
      f
    end

    it "creates parser and class parse method on it" do
      expect(subject).to receive(:create_parser).with("bucket", "key", "data", opts).and_return parser
      expect(parser).to receive(:parse).with("data", opts)
      expect(subject).to receive(:parser_class_name).with(parser).and_return "ParserClass"

      subject.parse("data", opts)

      expect(inbound_file.parser_name).to eq "ParserClass"
    end
  end

  describe "create_parser" do
    it "raises an error by default if the method is not overridden" do
      expect { subject.create_parser nil, nil, nil, nil }.to raise_error "All including classes must implement a create_parser class method that will return the brokered parser to utilize to process the given data." # rubocop:disable Format/LineLength
    end
  end
end