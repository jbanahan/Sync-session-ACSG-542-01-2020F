require 'spec_helper'

describe OpenChain::CustomHandler::Polo::Polo850Parser do

  describe "integration_folder" do
    it "uses correct folder" do
      expect(described_class.integration_folder).to eq ["polo/_polo_850", "/home/ubuntu/ftproot/chainroot/polo/_polo_850"]
    end
  end

  describe "parse" do
    let (:standard_xml) {
'<?xml version="1.0"?><Orders Version="1.0">
  <MessageInformation>
    <MessageDate>2016-04-24</MessageDate>
    <MessageTime>0831</MessageTime>
    <MessageOrderNumber>4700447521</MessageOrderNumber>
    <OrderChangeType>22</OrderChangeType>
  </MessageInformation>
  <Parties>
    <NameAddress>
      <PartyID>
        <PartyIDType>SU</PartyIDType>
        <PartyIDTypeDesc>LANTRAL CO LTD</PartyIDTypeDesc>
        <PartyIDValue>0200000363</PartyIDValue>
      </PartyID>
      <Street>
        <Street1>4 HOK YEUN STREET EAST</Street1>
        <Street2>HENG NGAI JEWELRY CENTRE, ROOM 1203</Street2>
      </Street>
      <City>HUNGHOM</City>
      <State></State>
      <PostalCode></PostalCode>
      <Country>HK</Country>
    </NameAddress>
  </Parties>
  <Lines>
    <ProductLine>
      <PositionNumber>00010</PositionNumber>
      <ProductDetails3>
        <ProductID>
          <ProductIDType>VA</ProductIDType>
          <ProductIDValue>209629423004</ProductIDValue>
        </ProductID>
      </ProductDetails3>
      <ProductQuantityDetails>
        <ProductQuantityUOM>EA</ProductQuantityUOM>
        <QuantityOrdered>46</QuantityOrdered>
      </ProductQuantityDetails>
      <ProductDescriptions>
        <ItemDescription>S1640X12J</ItemDescription>
        <ItemCharacteristicsType>X</ItemCharacteristicsType>
        <ItemCharacteristicsDescriptionCode>S1640X12J</ItemCharacteristicsDescriptionCode>
        <ItemCharacteristicsDescriptionCodeDesc>BRD</ItemCharacteristicsDescriptionCodeDesc>
      </ProductDescriptions>
      <ProductDescriptions>
        <ItemDescription>W LRL APP MISSY JEANS</ItemDescription>
        <ItemCharacteristicsType>X</ItemCharacteristicsType>
        <ItemCharacteristicsDescriptionCode>209</ItemCharacteristicsDescriptionCode>
        <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
      </ProductDescriptions>
      <ProductDescriptions>
        <ItemDescription>Fall 2016</ItemDescription>
        <ItemCharacteristicsType>X</ItemCharacteristicsType>
        <ItemCharacteristicsDescriptionCode>164</ItemCharacteristicsDescriptionCode>
        <ItemCharacteristicsDescriptionCodeDesc>SNM</ItemCharacteristicsDescriptionCodeDesc>
      </ProductDescriptions>
      <ProductDates>
        <DatesTimes>
          <DateTimeType>065</DateTimeType>
          <Date>2016-06-28</Date>
        </DatesTimes>
      </ProductDates>
      <ProductDates>
        <DatesTimes>
          <DateTimeType>118</DateTimeType>
          <Date>2016-06-29</Date>
        </DatesTimes>
      </ProductDates>
      <Transport>
        <ModeOfTransport>Ocean</ModeOfTransport>
        <ModeOfTransportCode>S</ModeOfTransportCode>
      </Transport>
    </ProductLine>
  </Lines>
</Orders>'
    }
    let (:prepack_xml) {
'<?xml version="1.0"?><Orders Version="1.0">
  <MessageInformation>
    <MessageDate>2016-04-24</MessageDate>
    <MessageTime>0831</MessageTime>
    <MessageOrderNumber>4700447521</MessageOrderNumber>
    <OrderChangeType>22</OrderChangeType>
  </MessageInformation>
  <Parties>
    <NameAddress>
      <PartyID>
        <PartyIDType>SU</PartyIDType>
        <PartyIDTypeDesc>LANTRAL CO LTD</PartyIDTypeDesc>
        <PartyIDValue>0200000363</PartyIDValue>
      </PartyID>
      <Street>
        <Street1>4 HOK YEUN STREET EAST</Street1>
        <Street2>HENG NGAI JEWELRY CENTRE, ROOM 1203</Street2>
      </Street>
      <City>HUNGHOM</City>
      <State></State>
      <PostalCode></PostalCode>
      <Country>HK</Country>
    </NameAddress>
  </Parties>
  <Lines>
    <ProductLine>
      <PositionNumber>00010</PositionNumber>
      <ProductDetails2>
        <ProductID>
          <ProductIDType>PK</ProductIDType>
          <ProductIDValue>AAB</ProductIDValue>
        </ProductID>
      </ProductDetails2>
      <ProductDetails3>
        <ProductID>
          <ProductIDType>VA</ProductIDType>
          <ProductIDValue>209629423004AAB</ProductIDValue>
        </ProductID>
      </ProductDetails3>
      <ProductQuantityDetails>
        <ProductQuantityUOM>EA</ProductQuantityUOM>
        <QuantityOrdered>46</QuantityOrdered>
      </ProductQuantityDetails>
      <ProductDescriptions>
        <ItemDescription>Fall 2016</ItemDescription>
        <ItemCharacteristicsType>X</ItemCharacteristicsType>
        <ItemCharacteristicsDescriptionCode>164</ItemCharacteristicsDescriptionCode>
        <ItemCharacteristicsDescriptionCodeDesc>SNM</ItemCharacteristicsDescriptionCodeDesc>
      </ProductDescriptions>
      <ProductDates>
        <DatesTimes>
          <DateTimeType>065</DateTimeType>
          <Date>2016-06-28</Date>
        </DatesTimes>
      </ProductDates>
      <ProductDates>
        <DatesTimes>
          <DateTimeType>118</DateTimeType>
          <Date>2016-06-28</Date>
        </DatesTimes>
      </ProductDates>
      <Transport>
        <ModeOfTransport>Ocean</ModeOfTransport>
        <ModeOfTransportCode>S</ModeOfTransportCode>
      </Transport>
      <SubLine>
        <SubLinePositionNumber>000100008</SubLinePositionNumber>
        <SubLinePositionNumber2>33</SubLinePositionNumber2>
        <ProductDetails>
          <ProductID>
            <ProductIDType></ProductIDType>
            <ProductIDValue></ProductIDValue>
          </ProductID>
        </ProductDetails>
        <ProductDetails2>
          <ProductID>
            <ProductIDType></ProductIDType>
            <ProductIDValue></ProductIDValue>
          </ProductID>
        </ProductDetails2>
        <ProductDetails3>
          <ProductID>
            <ProductIDType>SZ</ProductIDType>
            <ProductIDValue>XS</ProductIDValue>
          </ProductID>
        </ProductDetails3>
        <ProductDetails4>
          <ProductID>
            <ProductIDType>UP</ProductIDType>
            <ProductIDValue>190232578740</ProductIDValue>
          </ProductID>
        </ProductDetails4>
        <ProductDetails5>
          <ProductID>
            <ProductIDType>SM</ProductIDType>
            <ProductIDValue>21400</ProductIDValue>
          </ProductID>
        </ProductDetails5>
        <ProductQuantityDetails>
          <ProductQuantity>2</ProductQuantity>
        </ProductQuantityDetails>
        <ProductPricesAndTaxes>
          <UnitPrice>12.8</UnitPrice>
          <ProductQuantityUOM>EA</ProductQuantityUOM>
          <PriceIDCode>FCP</PriceIDCode>
          <PriceIDCodeDesc>MF</PriceIDCodeDesc>
          <PriceIDValue>12.8</PriceIDValue>
          <PriceIDCode>MSR</PriceIDCode>
          <PriceIDCodeDesc>RS</PriceIDCodeDesc>
          <PriceIDValue>125</PriceIDValue>
        </ProductPricesAndTaxes>
        <ProductDescriptions>
          <ItemDescription>S1640X12J</ItemDescription>
          <ItemCharacteristicsType>X</ItemCharacteristicsType>
          <ItemCharacteristicsDescriptionCode>S1640X12J</ItemCharacteristicsDescriptionCode>
          <ItemCharacteristicsDescriptionCodeDesc>BRD</ItemCharacteristicsDescriptionCodeDesc>
        </ProductDescriptions>
        <ProductDescriptions>
          <ItemDescription>W LRL APP MISSY JEANS</ItemDescription>
          <ItemCharacteristicsType>X</ItemCharacteristicsType>
          <ItemCharacteristicsDescriptionCode>209</ItemCharacteristicsDescriptionCode>
          <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
        </ProductDescriptions>
      </SubLine>
      <SubLine>
        <SubLinePositionNumber>000100006</SubLinePositionNumber>
        <SubLinePositionNumber2>34</SubLinePositionNumber2>
        <ProductDetails>
          <ProductID>
            <ProductIDType></ProductIDType>
            <ProductIDValue></ProductIDValue>
          </ProductID>
        </ProductDetails>
        <ProductDetails2>
          <ProductID>
            <ProductIDType></ProductIDType>
            <ProductIDValue></ProductIDValue>
          </ProductID>
        </ProductDetails2>
        <ProductDetails3>
          <ProductID>
            <ProductIDType>SZ</ProductIDType>
            <ProductIDValue>S</ProductIDValue>
          </ProductID>
        </ProductDetails3>
        <ProductDetails4>
          <ProductID>
            <ProductIDType>UP</ProductIDType>
            <ProductIDValue>190232578726</ProductIDValue>
          </ProductID>
        </ProductDetails4>
        <ProductDetails5>
          <ProductID>
            <ProductIDType>SM</ProductIDType>
            <ProductIDValue>20602</ProductIDValue>
          </ProductID>
        </ProductDetails5>
        <ProductQuantityDetails>
          <ProductQuantity>7</ProductQuantity>
        </ProductQuantityDetails>
        <ProductPricesAndTaxes>
          <UnitPrice>12.8</UnitPrice>
          <ProductQuantityUOM>EA</ProductQuantityUOM>
          <PriceIDCode>FCP</PriceIDCode>
          <PriceIDCodeDesc>MF</PriceIDCodeDesc>
          <PriceIDValue>12.8</PriceIDValue>
          <PriceIDCode>MSR</PriceIDCode>
          <PriceIDCodeDesc>RS</PriceIDCodeDesc>
          <PriceIDValue>125</PriceIDValue>
        </ProductPricesAndTaxes>
        <ProductDescriptions>
          <ItemDescription>Board2</ItemDescription>
          <ItemCharacteristicsType>X</ItemCharacteristicsType>
          <ItemCharacteristicsDescriptionCode>S1640X12J</ItemCharacteristicsDescriptionCode>
          <ItemCharacteristicsDescriptionCodeDesc>BRD</ItemCharacteristicsDescriptionCodeDesc>
        </ProductDescriptions>
        <ProductDescriptions>
          <ItemDescription>Another Division</ItemDescription>
          <ItemCharacteristicsType>X</ItemCharacteristicsType>
          <ItemCharacteristicsDescriptionCode>209</ItemCharacteristicsDescriptionCode>
          <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
        </ProductDescriptions>
      </SubLine>
    </ProductLine>
  </Lines>
</Orders>'
    }
    let (:master_company) { Factory(:master_company) }
    let (:cdefs) { subject.instance_variable_get(:@cdefs)}
    let (:log) { InboundFile.new }

    before :each do
      master_company
    end

    it "processes xml into order" do
      described_class.parse_file standard_xml, log, bucket: "bucket", key: "file.txt"
      order = Order.where(importer_id: master_company.id, order_number: "4700447521").first
      expect(order).not_to be_nil

      expect(order.last_file_bucket).to eq "bucket"
      expect(order.last_file_path).to eq "file.txt"
      expect(order.customer_order_number).to eq "4700447521"
      expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-04-24 08:31").in_time_zone Time.zone
      expect(order.season).to eq "Fall 2016"
      expect(order.custom_value(cdefs[:ord_division])).to eq "W LRL APP MISSY JEANS"

      expect(order.entity_snapshots.length).to eq 1
      expect(order.entity_snapshots.first.user).to eq User.integration

      vendor = Company.vendors.first
      expect(vendor).not_to be_nil
      expect(vendor.system_code).to eq "0200000363"
      expect(vendor.name).to eq "LANTRAL CO LTD"
      expect(order.vendor).to eq vendor

      expect(order.order_lines.length).to eq 1
      line = order.order_lines.first
      expect(line.line_number).to eq 10
      expect(line.quantity).to eq 46
      expect(line.unit_of_measure).to eq "EA"
      expect(line.custom_value(cdefs[:ord_line_ex_factory_date])).to eq Date.new(2016, 6, 29)
      expect(line.custom_value(cdefs[:ord_line_ship_mode])).to eq "Ocean"
      expect(line.custom_value(cdefs[:ord_line_board_number])).to eq "S1640X12J"

      p = line.product
      expect(p.unique_identifier).to eq "209629423004"

      expect(p.importer).to be_nil

      expect(log.company).to eq master_company
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq "4700447521"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq "Order"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq order.id
    end

    it "reuses an order" do
      order = Order.create! importer_id: master_company.id, order_number: "4700447521", customer_order_number: "4700447521"
      line = order.order_lines.create! line_number: 42, product: Factory(:product)

      described_class.parse_file standard_xml, log

      order.reload
      expect(order.order_lines).not_to include line
      expect(order.order_lines.length).to eq 1
    end

    it "re-uses a product" do
      product = Factory(:product, unique_identifier: "209629423004")
      described_class.parse_file standard_xml, log
      order = Order.where(importer_id: master_company.id, order_number: "4700447521").first
      expect(order).not_to be_nil
      expect(order.order_lines.first.product).to eq product
    end

    it "does not reprocess files if source export date is newer than file" do
      order = Order.create! importer_id: master_company.id, order_number: "4700447521", customer_order_number: "4700447521", last_exported_from_source: Time.zone.now
      described_class.parse_file standard_xml, log
      order.reload
      expect(order.order_lines.length).to eq 0
    end

    it "extracts division and board number from prepack lines" do
      described_class.parse_file prepack_xml, log
      order = Order.where(importer_id: master_company.id, order_number: "4700447521").first
      expect(order).not_to be_nil
      expect(order.custom_value(cdefs[:ord_division])).to eq "W LRL APP MISSY JEANS"
      line = order.order_lines.first
      # If there are multiple board numbers, it makes a csv of them
      expect(line.custom_value(cdefs[:ord_line_board_number])).to eq "S1640X12J, Board2"
    end

    it "strips the pack code from the style on prepack lines" do
      described_class.parse_file prepack_xml, log
      order = Order.where(importer_id: master_company.id, order_number: "4700447521").first
      expect(order).not_to be_nil

      expect(order.order_lines.first.product.unique_identifier).to eq "209629423004"
    end

    it "fails if master company can't be found" do
      master_company.destroy

      expect{described_class.parse_file prepack_xml, log}.to raise_error "Unable to find Master RL account.  This account should not be missing."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Unable to find Master RL account.  This account should not be missing."
    end
  end
end