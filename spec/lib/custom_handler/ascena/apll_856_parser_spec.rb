require 'spec_helper'
require 'rex12'

describe OpenChain::CustomHandler::Ascena::Apll856Parser do
  let :base_data do
    IO.read('spec/support/bin/ascena_apll_856.txt')
  end
  let :first_shipment_array do
    REX12::Document.parse(base_data)[2..44]
  end
  let :cdefs do
    {}
  end
  context 'IntegrationClientParser' do
    it "should respond to process_from_s3" do
      expect(described_class.respond_to?(:process_from_s3)).to be_truthy
    end
    it "should set integration folder" do
      expect(described_class.integration_folder).to eq "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_apll_asn"
    end
  end
  describe '#parse' do
    it "should split shipments and process" do
      expected_start_segments = []
      expected_end_elements = []
      9.times do |i|
        expected_start_segments << "ST*856*000#{i+1}"
        expected_end_elements << "000#{i+1}"
      end
      start_segments = []
      end_elements = []
      allow(described_class).to receive(:process_shipment) do |shipment_edi,cdefs|
        start_segments << shipment_edi.first.value
        end_elements << shipment_edi.last.elements.last.value
      end
      described_class.parse(base_data)
      expect(start_segments).to eq expected_start_segments
      expect(end_elements).to eq expected_end_elements
    end
    it "should email on EDI parse error" do
      expect(REX12::Document).to receive(:parse).with(base_data).and_raise REX12::ParseError.new("Parsing problem here.")
      described_class.parse(base_data)
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['edisupport@vandegriftinc.com']
      expect(mail.subject).to match(/Ascena\/APLL ASN EDI Processing Error/)
      expect(mail.body).to match(/Parsing problem here/)
    end
    it "should collect and email on shipment processing errors" do
      error_counter = 0
      expect(described_class).to receive(:process_shipment).exactly(9).times do
        error_counter += 1
        raise "Some shipment problem #{error_counter}"
      end
      described_class.parse(base_data)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['edisupport@vandegriftinc.com']
      expect(mail.subject).to match(/Ascena\/APLL ASN EDI Processing Error/)
      expect(mail.body).to match(/Some shipment problem 1/)
      expect(mail.body).to match(/Some shipment problem 9/)
    end
  end

  describe '#process_shipment' do
    let :ascena do
      Factory(:company,system_code:'ASCENA')
    end
    let :product do
      Factory(:product,unique_identifier:'ASCENA-415012')
    end
    let :order do
      Factory(:order_line,line_number:1,product:product,quantity:8771,order:Factory(:order,importer:ascena,order_number:'ASCENA-6225694')).order
    end
    let :ports do
      {
        cnxmn:Factory(:port,unlocode:'CNXMN',schedule_k_code:'12345'),
        uslgb:Factory(:port,unlocode:'USLGB',schedule_d_code:'4601')
      }
    end
    before :each do
      allow_any_instance_of(Shipment).to receive(:create_snapshot)
      allow(Lock).to receive(:acquire).and_yield
    end
    it "should create shipment" do
      expected_reference = 'ASCENA-XM1007980-HK956641'
      order #prep order data
      ports #prep port data
      expect_any_instance_of(Shipment).to receive(:create_snapshot).with(User.integration, nil, "path")
      expect(Lock).to receive(:acquire).with(expected_reference).and_yield
      expect {described_class.process_shipment(first_shipment_array,cdefs, last_file_bucket:"bucket", last_file_path: "path")}.to change(Shipment,:count).from(0).to(1)
      s = Shipment.first
      expect(s.reference).to eq expected_reference
      expect(s.importer).to eq ascena
      expect(s.master_bill_of_lading).to eq 'KKLUXM1007980'
      expect(s.booking_number).to eq 'HK956641'
      expect(s.est_departure_date).to eq Date.new(2016,11,22)
      expect(s.est_arrival_port_date).to eq Date.new(2016,12,5)
      expect(s.departure_date).to eq Date.new(2016,11,22)
      expect(s.vessel).to eq 'HAMBURG BRIDGE'
      expect(s.voyage).to eq '040E'
      expect(s.vessel_carrier_scac).to eq 'KKLU'
      expect(s.mode).to eq 'Ocean'
      expect(s.lading_port).to eq ports[:cnxmn]
      expect(s.unlading_port).to eq ports[:uslgb]
      expect(s.shipment_type).to eq "CY/CY"
      expect(s.last_file_bucket).to eq "bucket"
      expect(s.last_file_path).to eq "path"

      # container details
      expect(s.containers.count).to eq 1
      con = s.containers.first
      expect(con.container_number).to eq 'TTNU5430044'
      expect(con.seal_number).to eq 'TAD74582'

      expect(s.shipment_lines.count).to eq 1
      sl = s.shipment_lines.first
      expect(sl.container).to eq con
      expect(sl.product).to eq product
      expect(sl.order_lines.count).to eq 1
      expect(sl.order_lines.first).to eq order.order_lines.first
      expect(sl.quantity).to eq 8771
      expect(sl.carton_qty).to eq 799
      expect(sl.cbms).to eq 37.52
      expect(sl.gross_kgs).to eq 5490.2

      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
    it "should not fail on unknown LOCODE" do
      order #prep order data
      expect {described_class.process_shipment(first_shipment_array,cdefs)}.to change(Shipment,:count).from(0).to(1)
    end
    it "should not update existing shipments" do
      ascena
      Factory(:shipment,reference:'ASCENA-XM1007980-HK956641')
      expect(described_class.process_shipment(first_shipment_array,cdefs)).to be_nil
    end
    it "should record missing order in shipment" do
      shipment = described_class.process_shipment(first_shipment_array,cdefs)
      expect(shipment.marks_and_numbers).to eq "* Order Line not found for order ASCENA-6225694, style ASCENA-415012"
    end
    it "should fail if style not on order" do
      order
      base_data.gsub!('415012','999999')
      shipment = described_class.process_shipment(first_shipment_array,cdefs)
      expect(shipment.marks_and_numbers).to eq "* Order Line not found for order ASCENA-6225694, style ASCENA-999999"
    end
  end
end
