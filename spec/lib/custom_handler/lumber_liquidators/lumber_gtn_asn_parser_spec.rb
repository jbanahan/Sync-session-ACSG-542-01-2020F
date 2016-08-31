require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberGtnAsnParser do
  describe '#parse' do
    it 'should REXML parse and pass to parse_dom' do
      data = double('data')
      dom = double('dom')
      opts = double('opts')
      expect(REXML::Document).to receive(:new).with(data).and_return dom
      expect(described_class).to receive(:parse_dom).with dom, opts
      described_class.parse data, opts
    end
  end
  describe '#parse_dom' do
    before :each do
      allow_any_instance_of(Order).to receive(:create_snapshot)
      @test_data = IO.read('spec/fixtures/files/ll_gtn_asn.xml')
    end
    context 'success' do
      before :each do
        @cdefs = described_class.prep_custom_definitions [
          :ord_asn_arrived,:ord_asn_booking_approved,:ord_asn_booking_submitted,:ord_asn_departed,
          :ord_asn_discharged,:ord_asn_empty_return,:ord_asn_fcr_created,:ord_asn_gate_in,
          :ord_asn_gate_out,:ord_asn_loaded_at_port
        ]
      end
      it 'should update order' do
        po_number = '4500173883'
        ord = Factory(:order,order_number:po_number)
        expect_any_instance_of(Order).to receive(:create_snapshot).with User.integration
        described_class.parse_dom REXML::Document.new(@test_data)
        expect(ord.custom_value(@cdefs[:ord_asn_arrived])).to eq DateTime.iso8601('2016-08-01T12:50:00.000-07:00')
      end
    end
    context 'exceptions' do
      it 'should fail on wrong root element' do
        @test_data.gsub!(/ASNMessage/,'OtherRoot')
        expect{described_class.parse(@test_data)}.to raise_error(/OtherRoot/)
      end
      it 'should fail if order not found' do
        @test_data.gsub!(/4500173883/,'BADORDNUM')
        expect{described_class.parse(@test_data)}.to raise_error(/BADORDNUM/)
      end
    end

  end
end