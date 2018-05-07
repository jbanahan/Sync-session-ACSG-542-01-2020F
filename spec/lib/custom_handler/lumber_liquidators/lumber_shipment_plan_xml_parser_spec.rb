require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberShipmentPlanXmlParser do
  
  describe "parse_dom" do

    let (:test_data) { IO.read('spec/fixtures/files/ll_shipment_plan.xml') }
  
    it "should fail on bad root element" do
      test_data.gsub!(/ShipmentPlanMessage/,'BADROOT')
      doc = REXML::Document.new(test_data)
      expect{subject.parse_dom(doc)}.to raise_error("Incorrect root element, 'BADROOT'.  Expecting 'ShipmentPlanMessage'.")
    end

    it "should fail if shipment ref is missing" do
      test_data.gsub!(/2010371040/,'')
      doc = REXML::Document.new(test_data)
      expect{subject.parse_dom(doc)}.to raise_error("XML must have Shipment Reference Number at /ShipmentPlanList/ShipmentPlan/ShipmentPlanItemList/ShipmentPlanItem/SellerId.")
    end

    it "should fail if shipment plan name is missing" do
      test_data.gsub!(/730/,'')
      doc = REXML::Document.new(test_data)
      expect{subject.parse_dom(doc)}.to raise_error("XML must have Shipment Plan Name at /ShipmentPlanList/ShipmentPlan/ShipmentPlanHeader/ShipmentPlanName.")
    end

    it "should send an error email if the shipment can't be found" do
      doc = REXML::Document.new(test_data)
      subject.parse_dom(doc)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['ll-support@vandegriftinc.com']
      expect(mail.subject).to eq 'Lumber Liquidators Shipment Plan: Missing Shipment'
      expect(mail.body).to include ERB::Util.html_escape("A plan name was received for shipment '2010371040', but a shipment with a matching reference number could not be found.")
      expect(mail.attachments.length).to eq(0)
    end

    it "should update shipment" do
      opts = {key:'the_filename.xml'}
      shipment = Shipment.create!(reference:'2010371040')

      doc = REXML::Document.new(test_data)

      expect(Lock).to receive(:acquire).with('Shipment-2010371040').and_yield
      expect(Lock).to receive(:with_lock_retry).with(shipment).and_yield

      subject.parse_dom(doc, opts)

      shipment.reload
      expect(shipment.importer_reference).to eq('730')

      expect(shipment.entity_snapshots.length).to eq(1)
      snapshot = shipment.entity_snapshots[0]
      expect(snapshot.user).to eq(User.integration)
      expect(snapshot.context).to eq('the_filename.xml')

      # No error email.
      expect(ActionMailer::Base.deliveries.length).to eq(0)
    end
  end

end