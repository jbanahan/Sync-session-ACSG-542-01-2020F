require 'spec_helper'

describe OpenChain::CustomHandler::ShipmentParserSupport::OrdersChecker do
  
  subject { described_class }

  let(:prod1) { Factory(:product) }
  let(:prod2) { Factory(:product) }
  let(:ship1) { Factory(:shipment, reference: "REF1", booking_mode: "Ocean - FCL") }
  let(:ship2) { Factory(:shipment, reference: "REF2", booking_mode: "Ocean") }
  let(:ord1) { Factory(:order, order_number: "ORD1", customer_order_number: "CUSTORD1", mode: "Air", approval_status: "Accepted") }
  let(:ord2) { Factory(:order, order_number: "ORD2", customer_order_number: "CUSTORD2", mode: "Ocean", approval_status: "Accepted") }
  let(:ordln_1) { Factory(:order_line, order: ord1, product: prod1)}
  let(:ordln_2) { Factory(:order_line, order: ord2, product: prod2)}
  
  context "errors" do
    describe "flag_unaccepted" do
      it "raises exception if any order has 'unaccepted' status" do
        ord2
        ord1.update_attributes! approval_status: nil
        expect{ subject.flag_unaccepted ["ORD1", "ORD2"] }.to raise_error 'This file cannot be processed because the following orders are in an "unaccepted" state: CUSTORD1'
      end
    end
  end

  context "warnings" do
    describe "orders_with_mismatched_transport_mode" do
      it "returns customer-order numbers with mismatched transportation mode" do
        imp = Factory(:company)
        ship1.update_attributes importer: imp
        ord1.update_attributes importer: imp
        ord2.update_attributes importer: imp
        Factory(:order, importer: imp, order_number: "ORD3", customer_order_number: "CUSTORD3", mode: "Air")
        
        results = subject.orders_with_mismatched_transport_mode ["ORD1", "ORD2", "ORD3"], ship1
        expect(results).to eq(["CUSTORD1", "CUSTORD3"])
      end
    end

    context "manifests" do
      let(:shipln_1) {Factory(:shipment_line, shipment: ship1, product: prod1)}
      let(:shipln_2) {Factory(:shipment_line, shipment: ship2, product: prod2)}
      let!(:ps_1) { PieceSet.create! quantity: 1, order_line: ordln_1, shipment_line: shipln_1 }
      let!(:ps_2) { PieceSet.create! quantity: 1, order_line: ordln_2, shipment_line: shipln_2 }

      describe "orders_on_multi_manifests" do  
        it "returns customer-order numbers with matched shipment references" do
          results = subject.orders_on_multi_manifests ["ORD1", "ORD2"], "not included"
          expect(results).to eq({"CUSTORD1" => ["REF1"], "CUSTORD2" => ["REF2"]})
        end

        it "doesn't return rows that include specified reference number" do
          results = subject.orders_on_multi_manifests ["ORD1", "ORD2"], "REF1"
          expect(results).to eq({"CUSTORD2" => ["REF2"]})
        end

        it "doesn't include rows with unspecified order numbers" do
          results = subject.orders_on_multi_manifests ["ORD1"], "not included"
          expect(results).to eq({"CUSTORD1" => ["REF1"]})
        end
      end

      describe "warn_for_manifest" do
        it "throws exception either check fails" do
          s = instance_double(Shipment)
          expect(s).to receive(:reference).and_return "REF1"

          multi_manifest_output = {"CUSTORD1"=>["REF2", "REF3"]}
          mismatched_mode_output = ["CUSTORD1"]
          expect(subject).to receive(:orders_on_multi_manifests).with(["CUSTORD1"], "REF1").and_return multi_manifest_output
          expect(subject).to receive(:orders_with_mismatched_transport_mode).with(["CUSTORD1"], s).and_return mismatched_mode_output

          expect{ subject.warn_for_manifest(["CUSTORD1"], s) }.to raise_error "The following purchase orders are assigned to other shipments: CUSTORD1 (REF2, REF3) *** The following purchase orders have a mode of transport that doesn't match the assigned shipment: CUSTORD1"
        end

        it "return nil if both checks pass" do
          s = instance_double(Shipment)
          expect(s).to receive(:reference).and_return "REF1"

          expect(subject).to receive(:orders_on_multi_manifests).with(["CUSTORD1"], "REF1").and_return({})
          expect(subject).to receive(:orders_with_mismatched_transport_mode).with(["CUSTORD1"], s).and_return({})

          expect(subject.warn_for_manifest(["CUSTORD1"], s)).to be_nil
        end
      end
    end

    context "bookings" do
      let!(:booking_1) { Factory(:booking_line, shipment: ship1, order_line: ordln_1, product: prod1) }
      let!(:booking_2) { Factory(:booking_line, shipment: ship2, order_line: ordln_2, product: prod2) }

      describe "multi_booking_qry" do
        it "returns customer-order numbers with matched shipment references" do
          results = subject.orders_on_multi_bookings ["ORD1", "ORD2"], "not included"
          expect(results).to eq({"CUSTORD1" => ["REF1"], "CUSTORD2" => ["REF2"]})
        end

        it "doesn't include rows with unspecified order numbers" do
          results = subject.orders_on_multi_bookings ["ORD1", "ORD2"], "REF1"
          expect(results).to eq({"CUSTORD2" => ["REF2"]})
        end

        it "doesn't include rows with unspecified order numbers" do
          results = subject.orders_on_multi_bookings ["ORD1"], "not included"
          expect(results).to eq({"CUSTORD1" => ["REF1"]})
        end
      end

      describe "warn_for_bookings" do
        it "throws exception either check fails" do
          s = instance_double(Shipment)
          expect(s).to receive(:reference).and_return "REF1"

          multi_bookings_output = {"CUSTORD1"=>["REF2", "REF3"]}
          mismatched_mode_output = ["CUSTORD1"]
          expect(subject).to receive(:orders_on_multi_bookings).with(["CUSTORD1"], "REF1").and_return multi_bookings_output
          expect(subject).to receive(:orders_with_mismatched_transport_mode).with(["CUSTORD1"], s).and_return mismatched_mode_output

          expect{ subject.warn_for_bookings(["CUSTORD1"], s) }.to raise_error "The following purchase orders are assigned to other shipments: CUSTORD1 (REF2, REF3) *** The following purchase orders have a mode of transport that doesn't match the assigned shipment: CUSTORD1"
        end

        it "return nil if both checks pass" do
          s = instance_double(Shipment)
          expect(s).to receive(:reference).and_return "REF1"

          expect(subject).to receive(:orders_on_multi_bookings).with(["CUSTORD1"], "REF1").and_return({})
          expect(subject).to receive(:orders_with_mismatched_transport_mode).with(["CUSTORD1"], s).and_return({})

          expect(subject.warn_for_bookings(["CUSTORD1"], s)).to be_nil
        end
      end
    end
  end

  describe "raise_error" do
    it "raises an UnreportedError on webserver" do
      expect(InstanceInformation).to receive(:webserver?).and_return true
      expect { subject.raise_error "Test"}.to raise_error UnreportedError, "Test"
    end

    it "raises a StandardError not on webserver" do
      expect(InstanceInformation).to receive(:webserver?).and_return false
      expect { subject.raise_error "Test"}.to raise_error StandardError, "Test"
    end
  end


end
