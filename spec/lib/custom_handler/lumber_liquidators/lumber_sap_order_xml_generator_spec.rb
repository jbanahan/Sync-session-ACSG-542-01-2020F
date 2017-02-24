require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator do
  subject { described_class }

  before :each do
    allow(subject).to receive(:ftp_file)
  end

  let (:order) { Factory(:order, order_number: "PONUM") }

  describe "send_order" do
    it "should generate and FTP" do
      u = double('user')
      expect(User).to receive(:integration).and_return(u)
      xml = '<myxml></myxml>'
      tf = double('tempfile')
      expect(tf).to receive(:write).with(xml)
      expect(tf).to receive(:flush)
      expect(Tempfile).to receive(:open).with(["po_PONUM_",'.xml']).and_yield tf
      expect(subject).to receive(:ftp_file)
      expect(subject).to receive(:generate).with(u,order).and_return xml
      now = Time.zone.parse "2017-02-02 12:00"
      Timecop.freeze(now) { subject.send_order(order) }

      expect(order.sync_records.length).to eq 1
      sr = order.sync_records.first
      expect(sr.trading_partner).to eq "SAP PO"
      expect(sr.sent_at).to eq now
      expect(sr.confirmed_at).to eq (now + 1.minute)
    end
  end

  describe "generate" do
    it "should use ApiEntityXmlizer" do
      u = double('user')
      f = double('field_list')
      x = double('xmlizer')
      expect(OpenChain::Api::ApiEntityXmlizer).to receive(:new).and_return(x)
      expect(x).to receive(:entity_to_xml).with(u,order,f).and_return 'xml'
      expect(subject).to receive(:build_field_list).with(u).and_return f
      expect(subject.generate(u,order)).to eq 'xml'
    end
  end
end
