require 'spec_helper'

describe OpenChain::EmailProcessor do

  context "hm_shipment" do
    it "should process H&M shipment file" do
      u = double('user')
      allow(User).to receive(:integration).and_return u
      good_att = double("good_att")
      expect(good_att).to receive(:original_filename).and_return "VDI_INFO.LIS"
      expect(good_att).to receive(:read).and_return "HI"
      bad_att = double("bad_att")
      allow(bad_att).to receive(:original_filename).and_return "VDI_INFO.REPORT"
      email = Factory(:email,
        to:[
          { full: 'another@email.com', email: 'another@email.com', token: 'another', host: 'email.com', name: nil },
          { full: 'HM <HM_EDI@vandegriftinc.com>', email: 'HM_EDI@vandegriftinc.com', token: 'HM_EDI', host:'vandegriftinc.com', name: 'HM'}],
        attachments: [good_att,bad_att]
      )

      expect(OpenChain::CustomHandler::Hm::HmShipmentParser).to receive(:parse).with('HI',u)

      described_class.new(email).process
    end
  end
end