require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator do
  let(:cdefs){ subject.instance_variable_get("@cdefs") }

  describe '#create!' do
    let(:order) { Factory(:order, order_number:'ABC', vendor: Factory(:vendor)) }
    let(:purchasing_contact) { 
      order.vendor.update_custom_value! cdefs[:cmp_purchasing_contact_email], "me@there.com"
      "me@there.com"
    }

    before :each do
      cdefs
      stub_master_setup_request_host
    end

    it 'should create pdf and attach to order' do
      Timecop.freeze(Time.now) do
        described_class.create! order, Factory(:master_user)
        order.reload
        expect(order.attachments.size).to eq 1
        
        att = order.attachments.first
        expect(att.attachment_type).to eq 'Order Printout'
        expect(att.attached_file_name).to eq "order_ABC_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.pdf"
        expect(ActionMailer::Base.deliveries.size).to eq 0
      end
    end

    it "sends email to Purchasing Contact Email" do
      contact = purchasing_contact
      described_class.create! order, Factory(:master_user)

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [contact]
      expect(m.subject).to eq "Lumber Liquidators PO ABC - NEW"
      expect(m.body.raw_source).to include "You have received the attached purchase order from Lumber Liquidators.  If you have a VFI Track account, you may access the order at <a href=\"https://localhost:3000\">https://localhost:3000</a>"
    end

    it "sends email to Purchasing Content email notifying of updated po" do
      contact = purchasing_contact
      order.attachments.create! attachment_type: 'Order Printout'
      described_class.create! order, Factory(:master_user)

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [contact]
      expect(m.subject).to eq "Lumber Liquidators PO ABC - UPDATE"
    end
  end

  ##########################
  # NOT TESTING #render method 
  # which should be tested manually when modifying PDF generation
  ##########################
end