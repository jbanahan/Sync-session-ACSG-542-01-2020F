require 'spec_helper'
require 'rexml/document'

describe OpenChain::CustomHandler::LumberLiquidators::LumberGtnAsnParser do

  before :all do
    described_class.new.send(:cdefs)
  end

  after :all do
    CustomDefinition.destroy_all
  end

  let(:log) { InboundFile.new }

  describe 'parse' do
    it 'should REXML parse and pass to parse_dom' do
      data = double('data')
      dom = double('dom')
      opts = double('opts')
      expect(REXML::Document).to receive(:new).with(data).and_return dom
      expect(described_class).to receive(:parse_dom).with dom, log, opts
      described_class.parse_file data, log, opts
    end

    it 'should fail on wrong root element' do
      test_data = "<OtherRoot><Child>Hey!</Child></OtherRoot>"
      expect{described_class.parse_file(test_data, log)}.to raise_error('Bad root element name "OtherRoot". Expecting ASNMessage.')
      expect(ActionMailer::Base.deliveries.length).to eq 0
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq 'Bad root element name "OtherRoot". Expecting ASNMessage.'
    end
  end

  describe 'parse_dom' do
    before :each do
      @test_data = IO.read('spec/fixtures/files/ll_gtn_asn.xml')
      @ord = Factory(:order, order_number:'4500173883')
      @ord_2 = Factory(:order, order_number:'4500173884')
    end

    let (:cdefs) { subject.send(:cdefs) }

    it 'should update order and shipment with matching lines and containers' do
      shp = Factory(:shipment, reference:'201611221551')
      port_shanghai = Factory(:port, unlocode:'CNSHA')
      port_los_angeles = Factory(:port, unlocode:'USLAX')
      port_pomona = Factory(:port, unlocode:'USPQC')
      importer = Factory(:importer, system_code:'LUMBER')

      prod = Factory(:product, unique_identifier:'PRODXYZ')
      shp_container_1 = Factory(:container, container_number:'TEMU3877030', shipment:shp)
      shp_container_2 = Factory(:container, container_number:'TEMU3877031', shipment:shp)
      ord_line_1 = Factory(:order_line, product:prod, order:@ord, line_number:1)
      ord_line_2 = Factory(:order_line, product:prod, order:@ord_2, line_number:3)
      shp_line_1 = Factory(:shipment_line, shipment:shp, product:prod, container:shp_container_1, quantity:0, line_number: 1, carton_qty:5, gross_kgs:6.5)
      shp_line_1.piece_sets.create!(order_line:ord_line_1, quantity:0)
      shp_line_2 = Factory(:shipment_line, shipment:shp, product:prod, container:shp_container_2, quantity:0, line_number: 2, carton_qty:7, gross_kgs:5.6)
      shp_line_2.piece_sets.create!(order_line:ord_line_2, quantity:0)

      DataCrossReference.create! key:'20STD', value:'D20', cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE
      DataCrossReference.create! key:'45STD', value:'D45', cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE

      described_class.parse_dom REXML::Document.new(@test_data), log, { :key=>'s3_key_12345' }

      shp.reload
      shp_line_1.reload
      shp_line_2.reload
      shp_container_1.reload
      shp_container_2.reload
      ord_line_1.reload
      ord_line_2.reload

      expect(shp.master_bill_of_lading).to eq('EGLV142657648711')
      expect(shp.vessel_carrier_scac).to eq('EGLV')
      expect(shp.vessel).to eq('EVER LIVELY')
      expect(shp.voyage).to eq('0708-014E')
      expect(shp.lading_port).to eq(port_shanghai)
      expect(shp.unlading_port).to eq(port_los_angeles)
      expect(shp.final_dest_port).to eq(port_pomona)

      expect(shp.empty_out_at_origin_date).to eq DateTime.iso8601('2015-08-08T03:20:00.000-07:00')
      expect(shp.est_arrival_port_date).to eq DateTime.iso8601('2015-08-09T04:21:00.000-07:00').to_date
      expect(shp.est_departure_date).to eq DateTime.iso8601('2015-08-10T05:22:00.000-07:00').to_date
      expect(shp.empty_return_date).to eq DateTime.iso8601('2016-08-04T15:05:00.000-07:00')
      expect(shp.cargo_on_hand_date).to eq DateTime.iso8601('2016-07-14T01:50:00.000-07:00').to_date
      expect(shp.delivered_date).to eq DateTime.iso8601('2016-08-03T07:59:00.000-07:00').to_date
      expect(shp.container_unloaded_date).to eq DateTime.iso8601('2015-08-12T07:24:00.000-07:00')
      expect(shp.carrier_released_date).to eq DateTime.iso8601('2016-07-21T00:01:00.000-07:00')
      expect(shp.customs_released_carrier_date).to eq DateTime.iso8601('2015-08-14T09:26:00.000-07:00')
      expect(shp.available_for_delivery_date).to eq DateTime.iso8601('2016-08-02T09:55:00.000-07:00')
      expect(shp.full_ingate_date).to eq DateTime.iso8601('2015-08-15T10:27:00.000-07:00')
      expect(shp.full_out_gate_discharge_date).to eq DateTime.iso8601('2016-08-04T01:38:00.000-07:00')
      expect(shp.on_rail_destination_date).to eq DateTime.iso8601('2015-08-16T11:28:00.000-07:00')
      expect(shp.inland_port_date).to eq DateTime.iso8601('2015-08-17T12:29:00.000-07:00').to_date
      expect(shp.arrival_port_date).to eq DateTime.iso8601('2016-08-01T12:50:00.000-07:00').to_date
      expect(shp.departure_date).to eq DateTime.iso8601('2016-07-17T10:30:00.000-07:00').to_date
      expect(shp.full_container_discharge_date).to eq DateTime.iso8601('2016-08-02T09:55:00.000-07:00')
      expect(shp.confirmed_on_board_origin_date).to eq DateTime.iso8601('2016-07-16T16:27:00.000-07:00').to_date
      expect(shp.arrive_at_transship_port_date).to eq DateTime.iso8601('2015-08-18T13:30:00.000-07:00')
      expect(shp.departure_last_foreign_port_date).to eq DateTime.iso8601('2015-08-19T14:31:00.000-07:00').to_date
      expect(shp.barge_depart_date).to eq DateTime.iso8601('2015-08-20T15:32:00.000-07:00')
      expect(shp.barge_arrive_date).to eq DateTime.iso8601('2015-08-21T16:33:00.000-07:00')
      expect(shp.fcr_created_final_date).to eq DateTime.iso8601('2016-07-18T19:45:26.000-07:00')
      expect(shp.bol_date).to eq DateTime.iso8601('2016-07-17T12:00:00.000-07:00')
      expect(shp.last_exported_from_source).to eq Time.zone.parse("2016-08-04T17:20:27.000-07:00")

      expect(shp.containers.length).to eq 2
      expect(shp.containers[0].id).to eq shp_container_1.id
      expect(shp_container_1.container_number).to eq 'TEMU3877030'
      expect(shp_container_1.container_size).to eq '20STD'
      expect(shp_container_1.seal_number).to eq 'EMCBCZ9785'
      expect(shp_container_1.weight).to eq 15760

      expect(shp.containers[1].id).to eq shp_container_2.id
      expect(shp_container_2.container_number).to eq 'TEMU3877031'
      expect(shp_container_2.container_size).to eq '45STD'
      expect(shp_container_2.seal_number).to eq 'EMCBCZ9786'
      expect(shp_container_2.weight).to eq 15550

      expect(shp.shipment_lines.length).to eq 2
      expect(shp.shipment_lines[0].id).to eq shp_line_1.id
      expect(shp_line_1.quantity).to eq 22752.8
      expect(shp_line_1.piece_sets.first.quantity).to eq 22752.8
      expect(shp_line_1.cbms).to eq 13.7

      expect(shp.shipment_lines[1].id).to eq shp_line_2.id
      expect(shp_line_2.quantity).to eq 22852.7
      expect(shp_line_2.piece_sets.first.quantity).to eq 22852.7
      expect(shp_line_2.cbms).to eq 13.8

      shipment_snapshots = shp.entity_snapshots
      expect(shipment_snapshots.length).to eq 1
      expect(shipment_snapshots.first.context).to eq('s3_key_12345')
      expect(shipment_snapshots.first.user).to eq User.integration

      expect(@ord.custom_value(cdefs[:ord_asn_arrived])).to eq DateTime.iso8601('2016-08-01T12:50:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_departed])).to eq DateTime.iso8601('2016-07-17T10:30:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_discharged])).to eq DateTime.iso8601('2016-08-02T09:55:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_empty_return])).to eq DateTime.iso8601('2016-08-04T15:05:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_fcr_created])).to eq DateTime.iso8601('2016-07-18T19:45:26.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_gate_in])).to eq DateTime.iso8601('2016-07-14T01:50:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_gate_out])).to eq DateTime.iso8601('2016-08-04T01:38:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_loaded_at_port])).to eq DateTime.iso8601('2016-07-16T16:27:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_empty_out_gate_at_origin])).to eq DateTime.iso8601('2015-08-08T03:20:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_est_arrival_discharge])).to eq DateTime.iso8601('2015-08-09T04:21:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_est_departure])).to eq DateTime.iso8601('2015-08-10T05:22:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_delivered])).to eq DateTime.iso8601('2015-08-11T06:23:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_container_unloaded])).to eq DateTime.iso8601('2015-08-12T07:24:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_carrier_released])).to eq DateTime.iso8601('2015-08-13T08:25:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_customs_released_carrier])).to eq DateTime.iso8601('2015-08-14T09:26:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_available_for_delivery])).to eq DateTime.iso8601('2016-08-02T09:55:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_full_ingate])).to eq DateTime.iso8601('2015-08-15T10:27:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_on_rail_destination])).to eq DateTime.iso8601('2015-08-16T11:28:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_rail_arrived_destination])).to eq DateTime.iso8601('2015-08-17T12:29:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_arrive_at_transship_port])).to eq DateTime.iso8601('2015-08-18T13:30:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_depart_from_transship_port])).to eq DateTime.iso8601('2015-08-19T14:31:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_barge_depart])).to eq DateTime.iso8601('2015-08-20T15:32:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_barge_arrive])).to eq DateTime.iso8601('2015-08-21T16:33:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_bill_of_lading])).to eq 'EGLV142657648711'
      expect(@ord.custom_value(cdefs[:ord_bol_date])).to eq DateTime.iso8601('2016-07-17T12:00:00.000-07:00')

      expect(@ord_2.custom_value(cdefs[:ord_asn_available_for_delivery])).to eq DateTime.iso8601('2016-08-01T09:55:00.000-07:00')
      expect(@ord_2.custom_value(cdefs[:ord_bill_of_lading])).to eq 'EGLV142657648711'

      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_line_number])).to eq 1
      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_product])).to eq 'PRODXYZ'
      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_quantity])).to eq 22752.8
      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_cartons])).to eq 5
      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_volume])).to eq 13.7
      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_gross_weight])).to eq 6.5
      expect(ord_line_1.custom_value(cdefs[:ordln_shpln_container_number])).to eq 'TEMU3877030'

      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_line_number])).to eq 2
      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_product])).to eq 'PRODXYZ'
      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_quantity])).to eq 22852.7
      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_cartons])).to eq 7
      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_volume])).to eq 13.8
      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_gross_weight])).to eq 5.6
      expect(ord_line_2.custom_value(cdefs[:ordln_shpln_container_number])).to eq 'TEMU3877031'

      order_snapshots = @ord.entity_snapshots
      expect(order_snapshots.length).to eq 1
      expect(order_snapshots.first.context).to eq('s3_key_12345')
      expect(order_snapshots.first.user).to eq User.integration

      expect(@ord_2.entity_snapshots.length).to eq 1

      expect(ActionMailer::Base.deliveries.length).to eq 0

      expect(log.company).to eq importer
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].value).to eq '201611221551'
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_type).to eq "Shipment"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_id).to eq shp.id
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq '4500173883'
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq 'Order'
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq @ord.id
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[1].value).to eq '4500173884'
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[1].module_type).to eq 'Order'
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[1].module_id).to eq @ord_2.id
    end

    # Different date codes are used for some milestones in production.
    it 'should update order and shipment in simulated production production environment' do
      ms = stub_master_setup
      allow(ms).to receive(:production?).and_return true

      shp = Factory(:shipment, reference:'201611221551')

      prod = Factory(:product, unique_identifier:'PRODXYZ')
      shp_container_1 = Factory(:container, container_number:'TEMU3877030', shipment:shp)
      shp_container_2 = Factory(:container, container_number:'TEMU3877031', shipment:shp)
      ord_line_1 = Factory(:order_line, product:prod, order:@ord, line_number:1)
      ord_line_2 = Factory(:order_line, product:prod, order:@ord_2, line_number:3)
      shp_line_1 = Factory(:shipment_line, shipment:shp, product:prod, container:shp_container_1, quantity:0, line_number: 1, carton_qty:5, gross_kgs:6.5)
      shp_line_1.piece_sets.create!(order_line:ord_line_1, quantity:0)
      shp_line_2 = Factory(:shipment_line, shipment:shp, product:prod, container:shp_container_2, quantity:0, line_number: 2, carton_qty:7, gross_kgs:5.6)
      shp_line_2.piece_sets.create!(order_line:ord_line_2, quantity:0)

      described_class.parse_dom REXML::Document.new(@test_data), log, { :key=>'s3_key_12345' }

      shp.reload

      expect(shp.empty_out_at_origin_date).to eq DateTime.iso8601('2015-08-07T03:20:00.000-07:00')
      expect(shp.cargo_on_hand_date).to eq DateTime.iso8601('2016-07-15T01:50:00.000-07:00').to_date
      expect(shp.container_unloaded_date).to eq DateTime.iso8601('2015-08-11T07:24:00.000-07:00')
      expect(shp.available_for_delivery_date).to eq DateTime.iso8601('2016-08-01T09:55:00.000-07:00')
      expect(shp.full_ingate_date).to eq DateTime.iso8601('2015-08-14T10:27:00.000-07:00')
      expect(shp.inland_port_date).to eq DateTime.iso8601('2015-08-16T12:29:00.000-07:00').to_date
      expect(shp.barge_depart_date).to eq DateTime.iso8601('2015-08-21T15:32:00.000-07:00')
      expect(shp.barge_arrive_date).to eq DateTime.iso8601('2015-08-20T16:33:00.000-07:00')
      expect(shp.fcr_created_final_date).to eq DateTime.iso8601('2016-07-17T19:45:26.000-07:00')

      expect(@ord.custom_value(cdefs[:ord_asn_empty_out_gate_at_origin])).to eq DateTime.iso8601('2015-08-07T03:20:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_gate_in])).to eq DateTime.iso8601('2016-07-15T01:50:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_container_unloaded])).to eq DateTime.iso8601('2015-08-11T07:24:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_available_for_delivery])).to eq DateTime.iso8601('2016-08-01T09:55:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_full_ingate])).to eq DateTime.iso8601('2015-08-14T10:27:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_rail_arrived_destination])).to eq DateTime.iso8601('2015-08-16T12:29:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_barge_depart])).to eq DateTime.iso8601('2015-08-21T15:32:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_barge_arrive])).to eq DateTime.iso8601('2015-08-20T16:33:00.000-07:00')
      expect(@ord.custom_value(cdefs[:ord_asn_fcr_created])).to eq DateTime.iso8601('2016-07-17T19:45:26.000-07:00')

      expect(@ord_2.custom_value(cdefs[:ord_asn_available_for_delivery])).to eq DateTime.iso8601('2016-07-31T09:55:00.000-07:00')

      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it 'should update shipment with no existing lines or containers, missing ports, xrefs and BOL' do
      @test_data.gsub!(/EGLV142657648711/,'')

      shp = Factory(:shipment, reference:'201611221551', master_bill_of_lading:'old-BOL')

      prod = Factory(:product, unique_identifier:'PRODXYZ')
      ord_line_1 = Factory(:order_line, product:prod, order:@ord, line_number:1)
      # No second PO line.

      described_class.parse_dom REXML::Document.new(@test_data), log, { :key=>'s3_key_12345' }

      shp.reload

      # Master bill should not be blanked out even though there is no value in the XML.
      expect(shp.master_bill_of_lading).to eq('old-BOL')
      expect(shp.voyage).to eq('0708-014E')
      expect(shp.lading_port).to be_nil
      expect(shp.unlading_port).to be_nil
      expect(shp.final_dest_port).to be_nil

      expect(shp.containers.length).to eq 2
      shp_container_1 = shp.containers[0]
      expect(shp_container_1.container_number).to eq 'TEMU3877030'
      expect(shp_container_1.container_size).to be_nil

      shp_container_2 = shp.containers[1]
      expect(shp_container_2.container_number).to eq 'TEMU3877031'
      expect(shp_container_2.container_size).to be_nil

      # Only one line is created.
      expect(shp.shipment_lines.length).to eq 1
      shp_line_1 = shp.shipment_lines[0]
      expect(shp_line_1.quantity).to eq 22752.8
      expect(shp_line_1.piece_sets.first.quantity).to eq 22752.8
      expect(shp_line_1.product).to eq prod
      expect(shp_line_1.container).to eq shp_container_1
      expect(shp_line_1.piece_sets.first.order_line).to eq ord_line_1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['ll-support@vandegriftinc.com']
      expect(mail.subject).to eq 'Lumber GTN ASN Parser Errors: 201611221551'
      expect(mail.body).to include ERB::Util.html_escape("Errors were encountered while parsing ASN file for 201611221551.<br><br>Shipment did not contain a container TEMU3877030. A container record was created.<br>Shipment did not contain a manifest line for PO 4500173883, line 1. A manifest line record was created.<br>Shipment did not contain a container TEMU3877031. A container record was created.<br>Shipment did not contain a manifest line for PO 4500173884, line 3. A manifest line record could NOT be created because no matching PO line could be found.".html_safe)
      expect(mail.attachments.length).to eq 0

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[0].message).to eq "Shipment did not contain a container TEMU3877030. A container record was created."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[1].message).to eq "Shipment did not contain a manifest line for PO 4500173883, line 1. A manifest line record was created."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[2].message).to eq "Shipment did not contain a container TEMU3877031. A container record was created."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[3].message).to eq "Shipment did not contain a manifest line for PO 4500173884, line 3. A manifest line record could NOT be created because no matching PO line could be found."
    end

    it 'should fail when shipment cannot be found' do
      described_class.parse_dom REXML::Document.new(@test_data), log, { :key=>'s3_key_12345' }

      # Orders should not have been updated.
      expect(@ord.custom_value(cdefs[:ord_asn_arrived])).to be_nil
      expect(@ord.entity_snapshots.length).to eq 0
      expect(@ord_2.entity_snapshots.length).to eq 0

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['ll-support@vandegriftinc.com']
      expect(mail.subject).to eq 'Lumber GTN ASN Parser Errors: 201611221551'
      expect(mail.body).to include ERB::Util.html_escape("Errors were encountered while parsing ASN file for 201611221551.<br><br>ASN Failed because shipment not found in database: 201611221551.".html_safe)
      expect(mail.attachments.length).to eq 0

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "ASN Failed because shipment not found in database: 201611221551."
    end

    it 'should fail when order cannot be found' do
      shp = Factory(:shipment, reference:'201611221551')
      @ord.delete

      described_class.parse_dom REXML::Document.new(@test_data), log, { :key=>'s3_key_12345' }

      # Shipment should not have been updated.
      shp.reload
      expect(shp.master_bill_of_lading).to be_nil
      expect(shp.containers.length).to eq 0
      expect(shp.shipment_lines.length).to eq 0
      expect(shp.entity_snapshots.length).to eq 0

      # Second order should not have been updated either.
      expect(@ord_2.entity_snapshots.length).to eq 0

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['ll-support@vandegriftinc.com']
      expect(mail.subject).to eq 'Lumber GTN ASN Parser Errors: 201611221551'
      expect(mail.body).to include ERB::Util.html_escape("Errors were encountered while parsing ASN file for 201611221551.<br><br>ASN Failed because order(s) not found in database: 4500173883.".html_safe)
      expect(mail.attachments.length).to eq 0

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "ASN Failed because order(s) not found in database: 4500173883."
    end

    it 'should error when missing PO Number, but still update shipment' do
      @test_data.gsub!(/4500173883/,'')

      shp = Factory(:shipment, reference:'201611221551')

      prod = Factory(:product, unique_identifier:'PRODXYZ')
      ord_line_1 = Factory(:order_line, product:prod, order:@ord, line_number:1)
      ord_line_2 = Factory(:order_line, product:prod, order:@ord_2, line_number:3)

      described_class.parse_dom REXML::Document.new(@test_data), log, { :key=>'s3_key_12345' }

      shp.reload

      expect(shp.master_bill_of_lading).to eq('EGLV142657648711')
      expect(shp.containers.length).to eq 2

      expect(shp.shipment_lines.length).to eq 1
      shp_line_1 = shp.shipment_lines[0]
      expect(shp_line_1.piece_sets.first.order_line).to eq ord_line_2

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['ll-support@vandegriftinc.com']
      expect(mail.subject).to eq 'Lumber GTN ASN Parser Errors: 201611221551'
      expect(mail.body).to include ERB::Util.html_escape("Errors were encountered while parsing ASN file for 201611221551.<br><br>Shipment did not contain a container TEMU3877030. A container record was created.<br>LineItems in this file are missing PONumber and LineItemNumber values necessary to connect to shipment lines.<br>Shipment did not contain a container TEMU3877031. A container record was created.<br>Shipment did not contain a manifest line for PO 4500173884, line 3. A manifest line record was created.".html_safe)
      expect(mail.attachments.length).to eq 0

      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[0].message).to eq "Shipment did not contain a container TEMU3877030. A container record was created."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[1].message).to eq "LineItems in this file are missing PONumber and LineItemNumber values necessary to connect to shipment lines."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[2].message).to eq "Shipment did not contain a container TEMU3877031. A container record was created."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_WARNING)[3].message).to eq "Shipment did not contain a manifest line for PO 4500173884, line 3. A manifest line record was created."
    end

    it "skips updating shipment level information if xml is older than shipments last exported from source date, but still updates containers if container is not outdated" do
      shp = Factory(:shipment, reference:'201611221551', last_exported_from_source: "2019-01-01 12:00")

      expect(subject).not_to receive(:update_shipment)
      subject.parse_dom REXML::Document.new(@test_data), log, 's3_key_12345'

      shp.reload
      # The container should be there and there should be a snapshot
      expect(shp.entity_snapshots.length).to eq 1
      expect(shp.containers.find { |c| c.container_number == "TEMU3877030"}).not_to be_nil
      
      # The orders should also be updated
      expect(@ord.entity_snapshots.length).to eq 1
    end

    it "skips updating shipment / container level information if xml is older than shipment and container receipt dates" do
      shp = Factory(:shipment, reference:'201611221551', last_exported_from_source: "2019-01-01 12:00")
      Factory(:container, shipment: shp, container_number: "TEMU3877030", last_exported_from_source: "2019-01-01 12:00")
      Factory(:container, shipment: shp, container_number: "TEMU3877031", last_exported_from_source: "2019-01-01 12:00")
      
      subject.parse_dom REXML::Document.new(@test_data), log, 's3_key_12345'

      shp.reload
      # The container should be there and there should be a snapshot
      expect(shp.entity_snapshots.length).to eq 0
      
      # The orders should also be updated
      expect(@ord.entity_snapshots.length).to eq 0
      expect(@ord_2.entity_snapshots.length).to eq 0
    end
  end

end