require 'spec_helper'
require 'time'

describe OpenChain::CustomHandler::ISFXMLGenerator do
  describe 'generate' do
    before :each do
      importer = Factory(:importer, irs_number:'ashjdajdashdad', alliance_customer_number: 'asjhdajhdjasgd')
      consignee = Factory(:consignee, irs_number:'oijwofhiusfsdfhsdgf')
      @shipment = Factory(:shipment,
                          importer:importer,
                          consignee: consignee,
                          seller_address: Factory(:full_address),
                          buyer_address: Factory(:full_address),
                          ship_to_address: Factory(:full_address),
                          container_stuffing_address: Factory(:full_address),
                          consolidator_address: Factory(:full_address),
                          house_bill_of_lading:'this is a house bill',
                          master_bill_of_lading:'this is a master bill',
                          est_load_date: 3.days.ago.to_date,
                          booking_number: 'This is the number you booked',
      )
      order = Factory(:order, order_number:'123456789')
      3.times do
        product = Factory(:product)
        container = Factory(:container)
        line = Factory(:shipment_line, shipment:@shipment, product:product, container:container, quantity:100, manufacturer_address:Factory(:full_address))
        order_line = Factory(:order_line, order:order, quantity:100, product:product, country_of_origin:'GN')
        PieceSet.create(order_line:order_line, quantity:100, shipment_line:line)
      end
      first_line = @shipment.shipment_lines.first
      dup_line = Factory(:shipment_line, shipment:@shipment, product:first_line.product, container:first_line.container, quantity:100, manufacturer_address:first_line.manufacturer_address )
      PieceSet.create(order_line:order.order_lines.first, quantity:100, shipment_line:dup_line)
      @manufacturer_addresses = @shipment.shipment_lines.map(&:manufacturer_address).uniq
      allow_any_instance_of(ShipmentLine).to receive(:us_hts_number).and_return('123456789')
    end

    def match_address_entity_by_type(entity, address_type)
      address = case address_type
                  when 'SE'
                    @shipment.seller_address
                  when 'BY'
                    @shipment.buyer_address
                  when 'ST'
                    @shipment.ship_to_address
                  when 'LG'
                    @shipment.container_stuffing_address
                  when 'CS'
                    @shipment.consolidator_address
                  else
                    raise 'Invalid address type code'
                end
      match_address_entity(entity, address)
    end

    def match_address_entity(entity, address)
      expect(address).to be_present
      expect(entity.text('NAME')).to eq address.name
      expect(entity.text('ADDRESS_1')).to eq address.line_1
      expect(entity.text('CITY')).to eq address.city
      expect(entity.text('COUNTRY_SUBENTITY_CD')).to eq address.state
      expect(entity.text('POSTAL_CD')).to eq address.postal_code
      expect(entity.text('COUNTRY_CD')).to eq address.country.iso_code
    end

    def edi_line_matches_shipment_line?(edi_line, shipment_line)
      edi_line.text('PO_NBR') == shipment_line.order_lines.first.order.customer_order_number &&
      edi_line.text('TARIFF_CD') == shipment_line.us_hts_number &&
      edi_line.text('ORIGIN_COUNTRY_CD') == shipment_line.country_of_origin &&
      edi_line.text('CONTAINER_NBR') == shipment_line.container.container_number
    end

    it 'generates an XML file matching the spec' do
      c = described_class.new(@shipment.id, true)
      xml_document = c.send('generate')

      expect(xml_document).not_to be_nil
      r = xml_document.root

      expect(r.name).to eq 'IsfEdiUpload'
      expect(r.text('EDI_TXN_IDENTIFIER')).to eq @shipment.id.to_s
      expect(Time.parse(r.text('DATE_CREATED'))).to be_within(5.second).of(Time.now)
      expect(r.text('ACTION_CD')).to eq 'A'
      expect(r.text('IMPORTER_ACCT_CD')).to eq @shipment.importer.alliance_customer_number
      expect(Time.zone.parse(r.text('EST_LOAD_DATE')).to_date).to eq @shipment.est_load_date
      expect(r.text('BOOKING_NBR')).to eq @shipment.booking_number
      expect(r.text('EdiBillLading/HOUSE_BILL_NBR')).to eq ' is a house bill'
      expect(r.text('EdiBillLading/HOUSE_BILL_SCAC_CD')).to eq 'this'
      expect(r.text('EdiBillLading/MASTER_BILL_NBR')).to eq ' is a master bill'
      expect(r.text('EdiBillLading/MASTER_BILL_SCAC_CD')).to eq 'this'

      REXML::XPath.each(r,'EdiEntity') do |entity|
        case entity.text('ENTITY_TYPE_CD')
          when 'IM'
            expect(entity.text('BROKERAGE_ACCT_CD')).to eq @shipment.importer.alliance_customer_number
          when 'CN'
            expect(entity.text('ENTITY_ID')).to eq @shipment.consignee.irs_number
            expect(entity.text('ENTITY_ID_TYPE_CD')).to eq 'EI'
            expect(entity.text('NAME')).to eq @shipment.consignee.name
          when 'SE','BY','ST','LG','CS'
            match_address_entity_by_type(entity, entity.text('ENTITY_TYPE_CD'))
          when 'MF'
            index = entity.text('ENTITY_ID').to_i - 1
            match_address_entity(entity, @manufacturer_addresses[index])
          else
            raise 'All entity types should have test coverage'
        end
      end

      expect(REXML::XPath.each(r,'EdiLine').count).to eq @shipment.shipment_lines.count - 1

      # Every shipment line matches exactly one EdiLine
      expect(@shipment.shipment_lines.all? { |line| REXML::XPath.each(r,'EdiLine').select { |edi| edi_line_matches_shipment_line? edi, line }.count == 1 }).to eq true

    end

    it 'action code is R if the report has been run before' do
      c = described_class.new(@shipment.id, false)
      xml_document = c.send('generate')

      expect(xml_document).not_to be_nil
      r = xml_document.root
      expect(r.text('ACTION_CD')).to eq 'R'
    end
  end
end