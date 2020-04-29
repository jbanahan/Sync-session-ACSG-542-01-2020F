require Rails.root.join('spec/fixtures/files/standard_booking_form')
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

describe OpenChain::CustomHandler::GenericBookingParser do
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  context 'with valid data' do
    let!(:importer) { FactoryGirl.create :company, importer:true, system_code:'SYSTEM'}
    let!(:product) { FactoryGirl.create :product, unique_identifier:"#{importer.system_code}-WPT028533"}
    let!(:shipment) { FactoryGirl.create(:shipment, importer_id:importer.id) }
    let!(:first_order) { FactoryGirl.create :order, order_number: 2502377, customer_order_number: 1502377, importer_id:importer.id, approval_status: "Accepted"}
    let!(:second_order) { FactoryGirl.create :order, order_number: 2502396, customer_order_number: 1502396, importer_id:importer.id, approval_status: "Accepted" }
    let!(:third_order) { FactoryGirl.create :order, order_number: 2502397, customer_order_number: 1502397, importer_id:importer.id, approval_status: "Accepted" }
    let!(:fourth_order) { FactoryGirl.create :order, order_number: 2502398, customer_order_number: 1502398, importer_id:importer.id, approval_status: "Accepted" }
    let!(:order_lines) { [FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248678), FactoryGirl.create(:order_line, order_id: first_order.id, sku: 32248654), FactoryGirl.create(:order_line, order_id: second_order.id, sku: 32248838)]}
    let!(:user) { FactoryGirl.create(:master_user, shipment_edit: true, shipment_view: true) }
    let(:form_data) { StandardBookingFormSpecData.form_lines }

    before do
      # These results are based on the standard_booking_form fixture.
      # If that changes these tests will need to change!
    end

    it 'parses it correctly' do
      result = subject.process_rows shipment, form_data, user
      expect(result).to be_present

      expect(shipment.first_port_receipt).to be_nil
      expect(shipment.lading_port).to be_nil
      expect(shipment.unlading_port).to be_nil
      expect(shipment.destination_port).to be_nil

      expect(shipment.receipt_location).to eq "Sheerness, United Kingdom"
      expect(shipment.cargo_ready_date).to eq Date.parse("2015-05-25")
      expect(shipment.freight_terms).to eq  "Collect"
      expect(shipment.shipment_type).to eq "CFS/CY"
      expect(shipment.booking_shipment_type).to eq "CFS/CY"
      expect(shipment.lcl).to be false
      expect(shipment.mode).to eq "Ocean - LCL"
      expect(shipment.booking_mode).to eq "Ocean - LCL"

      # A bunch of lines in the standard booking form data are ignored because they don't have PO, etc.
      # These conditions are explored further in the 'incomplete data' tests.
      expect(shipment.booking_lines.length).to eq 3
      shipment.booking_lines.each do |line|
        expect(line).to be_persisted
      end

      line = shipment.booking_lines.first.reload
      expect(line.customer_order_number).to eq '1502377'
      expect(line.order_line.sku).to eq '32248678'
      expect(line.carton_qty).to eq 200
      expect(line.quantity).to eq 5000
      expect(line.cbms).to be_within(0.01).of 5.322
      expect(line.gross_kgs).to be_within(0.01).of 2142.200

      line = shipment.booking_lines[1].reload
      expect(line.customer_order_number).to eq '1502377'
      expect(line.order_line.sku).to eq '32248654'
      expect(line.carton_qty).to eq 145
      expect(line.quantity).to eq 3202
      expect(line.cbms).to be_within(0.01).of 3.456
      expect(line.gross_kgs).to be_within(0.01).of 1739.400

      line = shipment.booking_lines[2].reload
      expect(line.customer_order_number).to eq '1502396'
      expect(line.order_line.sku).to eq '32248838'
      expect(line.carton_qty).to eq 198
      expect(line.quantity).to eq 4676
      expect(line.cbms).to be_within(0.01).of 15.450
      expect(line.gross_kgs).to be_within(0.01).of 1920.000
    end

    it "handles CY/CY ship mode as Ocean - FCL" do
      values = form_data.dup
      values[30][11] = "CY/CY"

      result = subject.process_rows shipment, form_data, user
      expect(shipment.booking_shipment_type).to eq "CY/CY"
      expect(shipment.shipment_type).to eq "CY/CY"
      expect(shipment.mode).to eq "Ocean - FCL"
      expect(shipment.booking_mode).to eq "Ocean - FCL"
    end

    it "handles CY/CFS ship mode as Ocean - FCL" do
      values = form_data.dup
      values[30][11] = "CY/CFS"

      result = subject.process_rows shipment, form_data, user
      expect(shipment.booking_shipment_type).to eq "CY/CFS"
      expect(shipment.shipment_type).to eq "CY/CFS"
      expect(shipment.mode).to eq "Ocean - FCL"
      expect(shipment.booking_mode).to eq "Ocean - FCL"
    end

    it "handles CFS/CFS ship mode as Ocean - LCL" do
      values = form_data.dup
      values[30][11] = "CFS/CFS"

      result = subject.process_rows shipment, form_data, user
      expect(shipment.booking_shipment_type).to eq "CFS/CFS"
      expect(shipment.shipment_type).to eq "CFS/CFS"
      expect(shipment.mode).to eq "Ocean - LCL"
      expect(shipment.booking_mode).to eq "Ocean - LCL"
    end

    it "handles Ship Mode Air" do
      form_data[28][8] = "air"
      subject.process_rows shipment, form_data, user
      expect(shipment.booking_mode).to eq "Air"
      expect(shipment.mode).to eq "Air"
    end

    it "raises error when order/booking check fails if enable_warnings provided in constructor options" do
      ol = first_order.order_lines.first
      Factory(:booking_line, shipment: Factory(:shipment, reference: "2nd shipment"), order_line: ol)

      expect {described_class.new(enable_warnings: true).process_rows shipment, form_data, user}.to raise_error 'The following purchase orders are assigned to other shipments: 1502377 (2nd shipment)'
    end

    it "assigns warning_overridden attribs when enable_warnings is absent" do
      ol = first_order.order_lines.first
      Factory(:booking_line, shipment: Factory(:shipment, reference: "2nd shipment"), order_line: ol)

      Timecop.freeze(DateTime.new(2018, 1, 1)) { described_class.new(enable_warnings: false).process_rows shipment, form_data, user }
      expect(shipment.warning_overridden_by).to eq user
      expect(shipment.warning_overridden_at).to eq DateTime.new(2018, 1, 1)
    end

    it "throws exception if data contains unmatched order" do
      first_order.update_attributes! customer_order_number: "foo"
      expect {subject.process_rows shipment, form_data, user}.to raise_error "Order Number 1502377 not found."
      expect(BookingLine.count).to eq 0
    end
  end

  context 'with incomplete data' do
    let(:cdefs) { self.class.prep_custom_definitions([:prod_part_number]) }
    let(:importer) { Factory(:importer) }
    let(:shipment) { FactoryGirl.build :shipment, importer_id:importer.id }
    let (:product) {
      p = Factory(:product, importer: importer)
      p.update_custom_value! cdefs[:prod_part_number], "WPT028531"
      p
    }
    let!(:purchase_order) { FactoryGirl.create(:order, customer_order_number: 1502377, importer_id:importer.id)}
    let!(:order_lines) { [FactoryGirl.create(:order_line, order_id: purchase_order.id, sku: 32248678, product_id: product.id)]}
    let(:row) { [nil, "LIGHT & EASY LINEN-STRETCH PANTS (53% LINEN / 45% VISCOSE / 2% SPANDEX)", 1502377.0, "WPT028531", 32248678.0, "6204.69.9044", 200.0, 5000.0, nil, 5.322, 2142.2, "PH"] }

    it 'does not add a line when PO Number is not provided' do
      row[subject.file_layout[:po_column]] = ''
      subject.add_line_data shipment, row, 1
      expect(shipment.booking_lines.length).to eq 0
    end

    it 'does not add a line when SKU and Style are not provided' do
      row[subject.file_layout[:sku_column]] = ''
      row[subject.file_layout[:style_no_column]] = ''
      subject.add_line_data shipment, row, 1
      expect(shipment.booking_lines.length).to eq 0
    end

    it 'adds lines based on style if SKU is not provided' do
      row[subject.file_layout[:sku_column]] = ''
      subject.add_line_data shipment, row, 1
      expect(shipment.booking_lines.length).to eq 1

      line = shipment.booking_lines[0]
      expect(line.line_number).to eq 1
      expect(line.customer_order_number).to eq '1502377'
      # SKU is set by way of product linkage, which is made using style.
      expect(line.order_line.sku).to eq '32248678'
      expect(line.carton_qty).to eq 200
      expect(line.quantity).to eq 5000
      expect(line.cbms).to be_within(0.01).of 5.322
      expect(line.gross_kgs).to be_within(0.01).of 2142.200
    end
  end
end
