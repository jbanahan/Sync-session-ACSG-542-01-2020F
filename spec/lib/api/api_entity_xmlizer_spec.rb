describe OpenChain::Api::ApiEntityXmlizer do

  it "should defer do Jsonizer for hash" do
    # we're not unit testing the hash generation here,
    # so we need to make sure it's using an implementation
    # that is unit tested
    opts = {hello:'world'}
    u = double('user')
    e = double('entity')
    m = double('model_field_uids')
    j = double('jsonizer')
    eh = {}
    expect(OpenChain::Api::ApiEntityJsonizer).to receive(:new).with(opts).and_return j
    expect(j).to receive(:entity_to_hash).with(u, e, m).and_return eh
    expect_any_instance_of(described_class).to receive(:make_xml).with(e, eh).and_return 'xml'
    expect(described_class.new(opts).entity_to_xml(u, e, m)).to eq 'xml'
  end

  context 'with data' do

    let (:fields) { [:ord_ord_num, :ord_ord_date, :ordln_line_number, :ordln_puid, :ordln_ordered_qty] }
    let (:product) { Product.new unique_identifier: 'PUID' }
    let (:order_line) {  order.order_lines.first }
    let (:order) {
      order = Order.new order_number: "ORDNUM", order_date: Date.new(2016, 5, 1)
      order.id = 1
      line = order.order_lines.build line_number:1, quantity:10, product: product
      line.id = 2
      order
    }

    let (:expected_timestamp) { Time.now.utc.strftime("%Y-%m-%dT%l:%M:%S:%L%z") }

    before :each do
      Timecop.freeze(ActiveSupport::TimeZone["UTC"].parse("2017-02-28 12:15:000+0000"))
    end
    after :each do
      Timecop.return
    end
    it 'should create xml with base tag names' do
      xml = subject.entity_to_xml(Factory(:admin_user), order, fields)
      expect(xml).to eq IO.read('spec/fixtures/files/api_entity_xmlizer_sample.xml')
    end
    it 'should user xml_tag_overrides from ModelField' do
      cd = Factory(:custom_definition, module_type:'OrderLine', data_type:'string')
      FieldValidatorRule.create!(model_field_uid:cd.model_field_uid, xml_tag_name:'custom-tag')
      ModelField.reload
      order_line.find_and_set_custom_value(cd, 'myval')
      fields << cd.model_field_uid.to_sym
      expect(subject.entity_to_xml(Factory(:admin_user), order, fields)).to eq IO.read('spec/fixtures/files/api_entity_xmlizer_sample_custom_tag.xml')
    end
  end

  describe "xml_fingerprint" do
    it "returns SHA256 of XML" do
      # This also ends up verifying that the output style we're hashing is the compact output format.
      xml = "<?xml version='1.0' encoding='UTF-8'?><root/>"
      expect(subject.xml_fingerprint xml).to eq Digest::SHA256.hexdigest(xml)
    end

    it "strips xml-generated-time element by default" do
      xml = "<?xml version='1.0' encoding='UTF-8'?><root><xml-generated-time>123</xml-generated-time></root>"
      expect(subject.xml_fingerprint xml).to eq Digest::SHA256.hexdigest("<?xml version='1.0' encoding='UTF-8'?><root/>")
    end

    it "allows passing custom xpath elements to strip" do
      xml = "<?xml version='1.0' encoding='UTF-8'?><root><child><grandchild>data</grandchild></child></root>"
      expect(subject.xml_fingerprint xml, ignore_paths: ["/root/child"]).to eq Digest::SHA256.hexdigest("<?xml version='1.0' encoding='UTF-8'?><root/>")
    end

    it "does not strip xml-generated-time if another xpath set is given" do
      xml = "<?xml version='1.0' encoding='UTF-8'?><root><xml-generated-time>123</xml-generated-time></root>"
      expect(subject.xml_fingerprint xml, ignore_paths: ["/root/child"]).to eq Digest::SHA256.hexdigest(xml)
    end
  end
end
