require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberBookingConfirmationXmlParser do
  
  describe "parse_dom" do

    let (:test_data) { IO.read('spec/fixtures/files/ll_booking_confirmation.xml') }
  
    it "should fail on bad root element" do
      test_data.gsub!(/ShippingOrderMessage/,'BADROOT')
      doc = REXML::Document.new(test_data)
      expect{subject.parse_dom(doc)}.to raise_error("Incorrect root element, 'BADROOT'.  Expecting 'ShippingOrderMessage'.")
    end

    it "should fail if shipment ref is missing" do
      test_data.gsub!(/2018574260/,'')
      doc = REXML::Document.new(test_data)
      expect{subject.parse_dom(doc)}.to raise_error("XML must have Shipment Reference Number at /ShippingOrder/ShippingOrderNumber.")
    end

    it "should send an error email if the shipment can't be found" do
      doc = REXML::Document.new(test_data)
      subject.parse_dom(doc)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['ll-support@vandegriftinc.com']
      expect(mail.subject).to eq 'Lumber Liquidators Booking Confirmation: Missing Shipment'
      expect(mail.body).to include ERB::Util.html_escape("A booking confirmation was received for shipment '2018574260', but a shipment with a matching reference number could not be found.")
      expect(mail.attachments.length).to eq(0)
    end

    it "should update shipment" do
      opts = {key:'the_filename.xml'}
      shipment = Shipment.create!(reference:'2018574260')

      doc = REXML::Document.new(test_data)

      expect(Lock).to receive(:acquire).with('Shipment-2018574260').and_yield
      expect(Lock).to receive(:with_lock_retry).with(shipment).and_yield

      now = ActiveSupport::TimeZone['UTC'].parse('2018-02-01 16:30:12')
      Timecop.freeze(now) do
        subject.parse_dom(doc, opts)
      end

      shipment.reload
      expect(shipment.booking_number).to eq('CARRIERBKGNUM')
      expect(shipment.booking_cutoff_date).to eq(parse_date('2017-06-07T12:00:00.000-07:00').to_date)
      expect(shipment.booking_approved_date).to eq(parse_date('2017-06-05T12:00:00.000-07:00'))
      expect(shipment.booking_confirmed_date).to eq(now)
      expect(shipment.booking_est_departure_date).to eq(parse_date('2017-06-09T12:00:00.000-07:00').to_date)
      expect(shipment.est_departure_date).to eq(parse_date('2017-06-09T12:00:00.000-07:00').to_date)
      expect(shipment.booking_est_arrival_date).to eq(parse_date('2017-06-30T12:00:00.000-07:00').to_date)
      expect(shipment.booking_vessel).to eq('APL VENEZUELA')
      expect(shipment.vessel).to eq "APL VENEZUELA"
      expect(shipment.booking_voyage).to eq('1111')
      expect(shipment.voyage).to eq "1111"
      expect(shipment.booking_carrier).to eq('APLU')
      expect(shipment.vessel_carrier_scac).to eq "APLU"

      expect(shipment.entity_snapshots.length).to eq(1)
      snapshot = shipment.entity_snapshots[0]
      expect(snapshot.user).to eq(User.integration)
      expect(snapshot.context).to eq('the_filename.xml')

      # No error email.
      expect(ActionMailer::Base.deliveries.length).to eq(0)
    end

    # Ensures missing values don't cause exceptions to be thrown (nil-pointer, etc.).
    it "should handle missing carrier party and dates" do
      test_data.gsub!(/Carrier/,'Scarier')
      test_data.gsub!(/Date/,'Dirt')

      shipment = Shipment.create!(reference:'2018574260')

      doc = REXML::Document.new(test_data)

      expect(Lock).to receive(:acquire).with('Shipment-2018574260').and_yield
      expect(Lock).to receive(:with_lock_retry).with(shipment).and_yield

      subject.parse_dom(doc)

      shipment.reload
      expect(shipment.booking_cutoff_date).to be_nil
      expect(shipment.booking_approved_date).to be_nil
      expect(shipment.booking_est_departure_date).to be_nil
      expect(shipment.booking_est_arrival_date).to be_nil
      expect(shipment.booking_carrier).to be_nil
      # Verifying one other field is set is adequate.  No need to test them all.  That's done above.
      expect(shipment.booking_vessel).to eq('APL VENEZUELA')

      # No error email.
      expect(ActionMailer::Base.deliveries.length).to eq(0)
    end

    def parse_date date_str
      ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse date_str
    end
  end

end