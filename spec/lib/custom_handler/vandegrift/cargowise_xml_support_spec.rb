describe OpenChain::CustomHandler::Vandegrift::CargowiseXmlSupport do
  subject do
    Class.new do
      include OpenChain::CustomHandler::Vandegrift::CargowiseXmlSupport
    end.new
  end

  describe "unwrap_document_root" do

    let (:test_xml) do
      doc = Nokogiri::XML test_data
      doc.remove_namespaces!
      doc
    end
    let (:test_data) { IO.read('spec/fixtures/files/maersk_broker_invoice.xml') }

    it "Leaves documents alone that have UniversalTransaction as root element" do
      element = subject.unwrap_document_root(test_xml)
      expect(element.root.name).to eq "UniversalTransaction"
    end

    it "unwraps document and returns UniversalTransaction node" do
      test_data.prepend("<UniversalInterchange><Body>")
      test_data << "</Body></UniversalInterchange>"

      element = subject.unwrap_document_root(test_xml)

      expect(element.name).to eq "Body"
    end
  end
end