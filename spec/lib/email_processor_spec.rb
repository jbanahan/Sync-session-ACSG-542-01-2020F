require 'spec_helper'

describe OpenChain::EmailProcessor do

  context :hm_shipment do
    it "should process H&M shipment file" do
      u = double('user')
      User.stub(:integration).and_return u
      good_att = double("good_att")
      good_att.should_receive(:original_filename).and_return "VDI_INFO.LIS"
      good_att.should_receive(:read).and_return "HI"
      bad_att = double("bad_att")
      bad_att.stub(:original_filename).and_return "VDI_INFO.REPORT"
      email = Factory(:email,
        to:[
          { full: 'another@email.com', email: 'another@email.com', token: 'another', host: 'email.com', name: nil },
          { full: 'HM <HM_EDI@vandegriftinc.com>', email: 'HM_EDI@vandegriftinc.com', token: 'HM_EDI', host:'vandegriftinc.com', name: 'HM'}],
        attachments: [good_att,bad_att]
      )

      OpenChain::CustomHandler::Hm::HmShipmentParser.should_receive(:parse).with('HI',u)

      described_class.new(email).process
    end
  end
end