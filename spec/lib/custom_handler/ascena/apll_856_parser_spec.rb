require 'rex12'

describe OpenChain::CustomHandler::Ascena::Apll856Parser do
  let :base_data do
    IO.read('spec/support/bin/ascena_apll_856.txt')
  end
  let :first_shipment_array do
    REX12.each_segment(StringIO.new(base_data)).to_a[2..44]
  end

  let(:log) { InboundFile.new }

  context 'IntegrationClientParser' do
    it "should respond to process_from_s3" do
      expect(described_class.respond_to?(:process_from_s3)).to be_truthy
    end
    it "should set integration folder" do
      expect(described_class.integration_folder).to eq ["www-vfitrack-net/_ascena_apll_asn", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_apll_asn"]
    end
  end
  describe '#parse_file' do
    it "should split shipments and process" do
      expect_any_instance_of(described_class).to receive(:process_shipment).exactly(9).times
      described_class.parse_file(base_data, log)
    end
    it "should email on EDI parse error" do
      expect(REX12).to receive(:each_transaction).with(instance_of(StringIO)).and_raise REX12::ParseError.new("Parsing problem here.")
      described_class.parse_file(base_data, log)
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['edisupport@vandegriftinc.com']
      expect(mail.subject).to match(/Ascena\/APLL ASN EDI Processing Error/)
      expect(mail.body).to match(/Parsing problem here/)
    end
    it "should collect and email on shipment processing errors" do
      error_counter = 0
      expect_any_instance_of(described_class).to receive(:process_shipment).exactly(9).times do
        error_counter += 1
        raise "Some shipment problem #{error_counter}"
      end
      described_class.parse_file(base_data, log)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['edisupport@vandegriftinc.com']
      expect(mail.subject).to match(/Ascena\/APLL ASN EDI Processing Error/)
      expect(mail.body).to match(/Some shipment problem 1/)
      expect(mail.body).to match(/Some shipment problem 9/)
    end
  end

  describe '#process_shipment' do
    let :ascena do
      create(:company, system_code:'ASCENA')
    end
    let :product do
      create(:product, unique_identifier:'ASCENA-415012')
    end
    let :order do
      create(:order_line, line_number:1, product:product, quantity:8771, order:create(:order, importer:ascena, order_number:'ASCENA-BRAND-6225694', customer_order_number: "6225694")).order
    end
    let :ports do
      {
        cnxmn:create(:port, unlocode:'CNXMN', schedule_k_code:'12345'),
        uslgb:create(:port, unlocode:'USLGB', schedule_d_code:'4601')
      }
    end
    before :each do
      allow_any_instance_of(Shipment).to receive(:create_snapshot)
      allow(Lock).to receive(:acquire).and_yield
    end
    it "should create shipment" do
      expected_reference = 'ASCENA-XM1007980-HK956641'
      order # prep order data
      ports # prep port data
      expect_any_instance_of(Shipment).to receive(:create_snapshot).with(User.integration, nil, "path")
      expect(Lock).to receive(:acquire).with(expected_reference).and_yield
      expect {subject.process_shipment(first_shipment_array, log, last_file_bucket:"bucket", last_file_path: "path")}.to change(Shipment, :count).from(0).to(1)
      s = Shipment.first
      expect(s.reference).to eq expected_reference
      expect(s.importer).to eq ascena
      expect(s.master_bill_of_lading).to eq 'KKLUXM1007980'
      expect(s.booking_number).to eq 'HK956641'
      expect(s.est_departure_date).to eq Date.new(2016, 11, 22)
      expect(s.est_arrival_port_date).to eq Date.new(2016, 12, 5)
      expect(s.departure_date).to eq Date.new(2016, 11, 22)
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

      expect(log.company).to eq ascena
      expect(log).to have_identifier(:shipment_number, "XM1007980-HK956641", Shipment, s.id)
      expect(log).to have_info_message("Shipment XM1007980-HK956641 created.")
    end
    it "should not fail on unknown LOCODE" do
      order # prep order data
      expect {subject.process_shipment(first_shipment_array, log)}.to change(Shipment, :count).from(0).to(1)
    end
    it "should not update existing shipments" do
      ascena
      s = create(:shipment, reference:'ASCENA-XM1007980-HK956641')
      expect(subject.process_shipment(first_shipment_array, log)).to be_nil

      expect(log.company).to eq ascena
      expect(log).to have_identifier(:shipment_number, "XM1007980-HK956641", Shipment, s.id)
      expect(log).to have_info_message "Shipment XM1007980-HK956641 already exists and was not updated."
    end
    it "should record missing order in shipment" do
      shipment = subject.process_shipment(first_shipment_array, log)
      expect(shipment.marks_and_numbers).to eq "* Order Line not found for order Ascena Order # 6225694, style 415012"
      expect(log).to have_reject_message "Order Line not found for order Ascena Order # 6225694, style 415012"
    end
    it "should fail if style not on order" do
      order
      base_data.gsub!('415012', '999999')
      shipment = subject.process_shipment(first_shipment_array, log)
      expect(shipment.marks_and_numbers).to eq "* Order Line not found for order Ascena Order # 6225694, style 999999"
      expect(log).to have_reject_message "Order Line not found for order Ascena Order # 6225694, style 999999"
    end
    it "should fail if style is blank" do
      order
      base_data.gsub!('415012', '      ')

      expect {subject.process_shipment(first_shipment_array, log)}.to raise_error "Style number is required in LIN segment position 4."
      expect(log).to have_reject_message "Style number is required in LIN segment position 4."
    end
  end
end
