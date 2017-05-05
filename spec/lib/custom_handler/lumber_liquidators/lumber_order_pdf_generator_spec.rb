require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator do
  let(:cdefs){ subject.instance_variable_get("@cdefs") }

  describe '#create!' do
    let(:order) { Factory(:order, order_number:'ABC', vendor: Factory(:vendor), order_date: Date.new(2016,3,15)) }
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

  describe "carb_statement" do
    let(:ord) { Factory(:order, order_date: Date.new(2017,12,11)) }
    
    it "returns pre-12/11/17 (inclusive) message" do
      expect(described_class.carb_statement ord).to eq "All Composite Wood Products contained in finished goods must be compliant to California 93120 Phase 2 for formaldehyde."
    end

    it "returns post-12/11/17 message" do
      ord.update_attributes(order_date: Date.new(2017,12,12))
      expect(described_class.carb_statement ord).to eq "All Composite Wood Products contained in finished goods must be TSCA TITLE VI Compliant, or must be compliant to California 93120 Phase 2 for formaldehyde if panels were manufactured before December 12, 2017."
    end
  
    it "uses 'created_at' if order date is blank" do
      ord.update_attributes(order_date: nil)
      expect(ord).to receive(:created_at).and_return Date.new(2017,12,11)
      expect(described_class.carb_statement ord).to eq "All Composite Wood Products contained in finished goods must be compliant to California 93120 Phase 2 for formaldehyde."
    end
  end

  ##########################
  # NOT TESTING #render method 
  # which should be tested manually when modifying PDF generation
  ##########################
end