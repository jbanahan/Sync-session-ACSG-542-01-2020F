describe OpenChain::CustomHandler::Hm::HmI977Parser do

  let(:xml_data) { IO.read 'spec/fixtures/files/hm_i977.xml' }
  
  describe "process_article" do
    let (:user) { Factory(:user) }
    let (:cdefs) { subject.cdefs }
    let! (:hm) { Factory(:importer, system_code: "HENNE") }
    let (:article_xml) {
      REXML::XPath.first(REXML::Document.new(xml_data), "/ns0:CustomsMasterDataTransaction/Payload/CustomsMasterData/Articles/Article")
    }
    let (:inbound_file) { InboundFile.new }

    before :each do
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses a single article xml into a product" do
      product = subject.process_article article_xml, user, "file.xml"
      expect(product).not_to be_nil
      product.reload

      expect(product.unique_identifier).to eq "HENNE-0475463"
      expect(product.name).to eq "Other shoe Black, 38"
      expect(product.custom_value(cdefs[:prod_part_number])).to eq "0475463"
      expect(product.custom_value(cdefs[:prod_product_group])).to eq "Men"
      expect(product.custom_value(cdefs[:prod_type])).to eq "Leather"
      expect(product.custom_value(cdefs[:prod_po_numbers])).to eq "302290\n 302292"
      expect(product.custom_value(cdefs[:prod_season])).to eq "201706"
      expect(product.custom_value(cdefs[:prod_suggested_tariff])).to eq "6117100000"
      expect(product.custom_value(cdefs[:prod_fabric_content])).to eq "100% Leather"

      expect(product.entity_snapshots.length).to eq 1
      s = product.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.xml"
      expect(inbound_file).to have_identifier(:article_number, "0475463", Product, product.id)
    end

    it "does not update parts where nothing has changed" do
      product = Product.create! unique_identifier: "HENNE-0475463", importer: hm, name: "Other shoe Black, 38"
      product.update_custom_value! cdefs[:prod_product_group], "Men"
      product.update_custom_value! cdefs[:prod_type], "Leather"
      product.update_custom_value! cdefs[:prod_po_numbers], "302290\n 302292"
      product.update_custom_value! cdefs[:prod_season], "201706"
      product.update_custom_value! cdefs[:prod_suggested_tariff], "6117100000"
      product.update_custom_value! cdefs[:prod_fabric_content], "100% Leather"

      expect(subject.process_article article_xml, user, "file.xml").to be_nil
      product.reload
      expect(product.entity_snapshots.length).to eq 0
    end

    it "uses an existing product, appending multiple po numbers and seasons" do
      product = Product.create! unique_identifier: "HENNE-0475463", importer: hm, name: "Other shoe Black, 38"
      product.update_custom_value! cdefs[:prod_po_numbers], "PO"
      product.update_custom_value! cdefs[:prod_season], "SEASON"

      p = subject.process_article article_xml, user, "file.xml"

      expect(p.custom_value(cdefs[:prod_po_numbers])).to eq "PO\n 302290\n 302292"
      expect(p.custom_value(cdefs[:prod_season])).to eq "SEASON\n 201706"
    end
  end

  describe "parse_file" do
    subject { described_class }

    it "reads file content and processes each article" do
      expect_any_instance_of(subject).to receive(:process_article).at_least(1).times do |parser, xml, user, filename|
        expect(parser).to be_a(described_class)
        expect(xml.name).to eq "Article"
        expect(user).to eq User.integration
        expect(filename).to eq 'file.xml'
      end

      subject.parse_file(xml_data, nil, {key: "file.xml"})
    end
  end
end