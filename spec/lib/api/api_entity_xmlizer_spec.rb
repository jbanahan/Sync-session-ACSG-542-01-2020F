require 'spec_helper'

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
    eh = double('entity_hash')
    OpenChain::Api::ApiEntityJsonizer.should_receive(:new).with(opts).and_return j
    j.should_receive(:entity_to_hash).with(u,e,m).and_return eh
    described_class.any_instance.should_receive(:make_xml).with(e,eh).and_return 'xml'
    expect(described_class.new(opts).entity_to_xml(u,e,m)).to eq 'xml'
  end

  context 'with data' do
    before :each do
      @order = Factory(:order,order_number:'ORDNUM',order_date:Date.new(2016,5,1))
      @product = Factory(:product,unique_identifier:'PUID')
      @order_line = Factory(:order_line,line_number:1,quantity:10,product:@product,order:@order)
      @fields = [
        :ord_ord_num,
        :ord_ord_date,
        :ordln_line_number,
        :ordln_puid,
        :ordln_ordered_qty
      ]
      @expected_xml = <<-xml
<?xml version="1.0" encoding="UTF-8"?>
<order>
  <id type="integer">#{@order.id}</id>
  <order-lines type="array">
    <order-line>
      <id type="integer">#{@order_line.id}</id>
      <ordln-line-number type="integer">1</ordln-line-number>
      <ordln-ordered-qty type="decimal">10.0</ordln-ordered-qty>
      <ordln-puid>PUID</ordln-puid>
    </order-line>
  </order-lines>
  <ord-ord-date type="date">2016-05-01</ord-ord-date>
  <ord-ord-num>ORDNUM</ord-ord-num>
</order>
xml
    end
    it 'should create xml with base tag names' do
      expected_xml = <<-xml
<?xml version="1.0" encoding="UTF-8"?>
<order>
  <id type="integer">#{@order.id}</id>
  <order-lines type="array">
    <order-line>
      <id type="integer">#{@order_line.id}</id>
      <ordln-line-number type="integer">1</ordln-line-number>
      <ordln-ordered-qty type="decimal">10.0</ordln-ordered-qty>
      <ordln-puid>PUID</ordln-puid>
    </order-line>
  </order-lines>
  <ord-ord-num>ORDNUM</ord-ord-num>
  <ord-ord-date type="date">2016-05-01</ord-ord-date>
</order>
xml
      expect(described_class.new.entity_to_xml(Factory(:admin_user),@order,@fields)).to eq expected_xml
    end
    it 'should user xml_tag_overrides from ModelField' do
      expected_xml = <<-xml
<?xml version="1.0" encoding="UTF-8"?>
<order>
  <id type="integer">#{@order.id}</id>
  <order-lines type="array">
    <order-line>
      <id type="integer">#{@order_line.id}</id>
      <ordln-line-number type="integer">1</ordln-line-number>
      <ordln-ordered-qty type="decimal">10.0</ordln-ordered-qty>
      <ordln-puid>PUID</ordln-puid>
      <custom-tag>myval</custom-tag>
    </order-line>
  </order-lines>
  <ord-ord-num>ORDNUM</ord-ord-num>
  <ord-ord-date type="date">2016-05-01</ord-ord-date>
</order>
xml
      cd = Factory(:custom_definition,module_type:'OrderLine',data_type:'string')
      FieldValidatorRule.create!(model_field_uid:cd.model_field_uid,xml_tag_name:'custom-tag')
      ModelField.reload
      @order_line.update_custom_value!(cd,'myval')
      @fields << cd.model_field_uid.to_sym
      expect(described_class.new.entity_to_xml(Factory(:admin_user),@order,@fields)).to eq expected_xml
    end
  end
end
