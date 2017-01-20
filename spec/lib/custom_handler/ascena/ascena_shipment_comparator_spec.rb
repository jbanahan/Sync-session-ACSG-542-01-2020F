require 'spec_helper'

describe OpenChain::CustomHandler::Ascena::AscenaShipmentComparator do

  subject { described_class }

  let (:ascena) { Factory(:importer, system_code: "ASCENA") }
  let (:shipment) { Factory(:shipment, importer: ascena) }

  describe "accept?" do
    let (:non_ascena_shipment) { Factory(:shipment, importer: Factory(:importer)) }
    let (:user) { Factory(:user)}

    it "accepts ascena shipments" do
      expect(subject.accept? shipment.entity_snapshots.create! user: user).to be_truthy
    end

    it "doesn't accept non-ascena shipments" do
      expect(subject.accept? non_ascena_shipment.entity_snapshots.create! user: user).to be_falsey
    end
  end

  describe "compare" do
    let (:generator) {
      instance_double(OpenChain::CustomHandler::Ascena::AscenaShipmentCiLoadGenerator)
    }
    it "sends ascena ci load file" do
      expect(subject).to receive(:ascena_generator).and_return generator
      expect(generator).to receive(:generate_and_send).with(shipment)

      now = Time.zone.now
      Timecop.freeze(now) do 
        subject.compare nil, shipment.id, nil, nil, nil, nil, nil, nil
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr.trading_partner).to eq "ASCE"
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
    end
  end
end