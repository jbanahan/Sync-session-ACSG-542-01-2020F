require 'spec_helper'

describe OpenChain::CustomHandler::ShipmentParserSupport do
  subject do 
    klass = described_class
    Class.new{ include klass }.new
  end

  let(:prod1) { Factory(:product) }
  let(:prod2) { Factory(:product) }
  let(:ship1) { Factory(:shipment, reference: "REF1") }
  let(:ship2) { Factory(:shipment, reference: "REF2") }
  let(:ord1) { Factory(:order, order_number: "ORD1", customer_order_number: "CUSTORD1") }
  let(:ord2) { Factory(:order, order_number: "ORD2", customer_order_number: "CUSTORD2") }
  let(:ordln_1) { Factory(:order_line, order: ord1, product: prod1)}
  let(:ordln_2) { Factory(:order_line, order: ord2, product: prod2)}
  
  context "multi manifests" do
    let(:shipln_1) {Factory(:shipment_line, shipment: ship1, product: prod1)}
    let(:shipln_2) {Factory(:shipment_line, shipment: ship2, product: prod2)}
    let!(:ps_1) { PieceSet.create! quantity: 1, order_line: ordln_1, shipment_line: shipln_1 }
    let!(:ps_2) { PieceSet.create! quantity: 1, order_line: ordln_2, shipment_line: shipln_2 }

    describe "multi_manifests_qry" do  
      it "returns customer-order numbers with matched shipment references" do
        results = ActiveRecord::Base.connection.execute(subject.multi_manifests_qry ["ORD1", "ORD2"], "not included")
        expect(results.count).to eq 2
        res = []
        results.each{ |r| res << r }
        expect(res[0]).to eq ["CUSTORD1", "REF1"]
        expect(res[1]).to eq ["CUSTORD2", "REF2"]
      end

      it "doesn't return rows that include specified reference number" do
        results = ActiveRecord::Base.connection.execute(subject.multi_manifests_qry ["ORD1", "ORD2"], "REF1")
        expect(results.count).to eq 1
        expect(results.first).to eq ["CUSTORD2", "REF2"]
      end

      it "doesn't include rows with unspecified order numbers" do
        results = ActiveRecord::Base.connection.execute(subject.multi_manifests_qry ["ORD1"], "not included")
        expect(results.count).to eq 1
        expect(results.first).to eq ["CUSTORD1", "REF1"]
      end
    end

    describe "orders_on_multi_manifests" do
      it "throws exception containing order/shipment matches if there are any" do
        expect{subject.orders_on_multi_manifests(["ORD1", "ORD2"], "foo")}.to raise_error 'ORDERS FOUND ON MULTIPLE SHIPMENTS: ~{"CUSTORD1":["REF1"],"CUSTORD2":["REF2"]}'
      end

      it "returns nil if there aren't any matches" do
        expect(subject.orders_on_multi_manifests(["no such ord 1", "no such ord 2"], "foo")).to be_nil
      end
    end
  end

  context "multi bookings" do
    let!(:booking_1) { Factory(:booking_line, shipment: ship1, order_line: ordln_1, product: prod1) }
    let!(:booking_2) { Factory(:booking_line, shipment: ship2, order_line: ordln_2, product: prod2) }

    describe "multi_booking_qry" do
      it "returns customer-order numbers with matched shipment references" do
        results = ActiveRecord::Base.connection.execute(subject.multi_bookings_qry ["ORD1", "ORD2"], "not included")
        expect(results.count).to eq 2
        res = []
        results.each{ |r| res << r }
        expect(res[0]).to eq ["CUSTORD1", "REF1"]
        expect(res[1]).to eq ["CUSTORD2", "REF2"]
      end

      it "doesn't include rows with unspecified order numbers" do
        results = ActiveRecord::Base.connection.execute(subject.multi_bookings_qry ["ORD1", "ORD2"], "REF1")
        expect(results.count).to eq 1
        expect(results.first).to eq ["CUSTORD2", "REF2"]
      end

      it "doesn't include rows with unspecified order numbers" do
        results = ActiveRecord::Base.connection.execute(subject.multi_bookings_qry ["ORD1"], "not included")
        expect(results.count).to eq 1
        expect(results.first).to eq ["CUSTORD1", "REF1"]
      end
    end

    describe "orders_on_multi_bookings" do
      it "throws exception containing order/shipment matches if there are any" do
        expect{subject.orders_on_multi_bookings(["ORD1", "ORD2"], "foo")}.to raise_error 'ORDERS FOUND ON MULTIPLE SHIPMENTS: ~{"CUSTORD1":["REF1"],"CUSTORD2":["REF2"]}'
      end 
      it "returns nil if there aren't any matches" do
        expect(subject.orders_on_multi_bookings(["no such ord 1", "no such ord 2"], "foo")).to be_nil
      end
     end
  end
end