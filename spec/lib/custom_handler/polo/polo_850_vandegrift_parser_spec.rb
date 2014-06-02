require 'spec_helper'

describe OpenChain::CustomHandler::Polo::Polo850VandegriftParser do

  describe :integration_folder do
    it "should use the correct folder" do
      described_class.new.integration_folder.should eq ["//opt/wftpserver/ftproot/www-vfitrack-net/_polo_850", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_polo_850"]
    end
  end

  describe :parse do
    context :standard_line_type do
      before :each do
        @part_no_cd = CustomDefinition.create! label: "Part Number", module_type: "Product", data_type: "string"
        @po_type = ""
        @po_number = "PO"
        @merchandise_division = "MERCH"
        @message_date = "2014-01-01"
        @message_time = "1200"
        @line_number = "00010"
        @style = "STYLE"
        @uom = "UOM"
        @quantity = "10"
        @buyer_id = "0200011989"
        @importer = Factory(:company, fenix_customer_number: "806167003RM0001")

        @xml_lambda = lambda do 
          <<-XML
<Orders>
  <MessageInformation>
    <MessageOrderNumber>#{@po_number}</MessageOrderNumber>
    <MessageDate>#{@message_date}</MessageDate>
    <MessageTime>#{@message_time}</MessageTime>
    <OrderChangeType>#{@po_type}</OrderChangeType>
  </MessageInformation>
  <Parties>
    <NameAddress>
      <PartyID>
        <PartyIDType>BY</PartyIDType>
        <PartyIDValue>#{@buyer_id}</PartyIDValue>
      </PartyID>
    </NameAddress>
  </Parties>
  <Lines>
    <ProductLine>
      <PositionNumber>#{@line_number}</PositionNumber>
      <ProductDetails3>
        <ProductID>
          <ProductIDValue>#{@style}</ProductIDValue>
        </ProductID>
      </ProductDetails3>
      <ProductQuantityDetails>
        <ProductQuantityUOM>#{@uom}</ProductQuantityUOM>
        <QuantityOrdered>#{@quantity}</QuantityOrdered>
      </ProductQuantityDetails>
      <ProductDescriptions>
        <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
        <ItemCharacteristicsDescriptionCode>#{@merchandise_division}</ItemCharacteristicsDescriptionCode>
      </ProductDescriptions>
    </ProductLine>
  </Lines>
</Orders>
XML
        end
      end

      it "should extract po and division code and create a Data Cross Reference Record" do
        described_class.new.parse @xml_lambda.call

        r = DataCrossReference.first
        r.cross_reference_type.should eq DataCrossReference::RL_PO_TO_BRAND
        r.key.should eq @po_number
        r.value.should eq @merchandise_division
      end

      it "should update existing cross reference records" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_PO_TO_BRAND, key: @po_number, value: "some_other_value"

        described_class.new.parse @xml_lambda.call

        r = DataCrossReference.first
        r.value.should eq @merchandise_division
      end

      it "saves XML information as an Order" do
        described_class.new.parse @xml_lambda.call, bucket: "bucket", key: "key"

        order = Order.where(order_number: "#{@importer.fenix_customer_number}-#{@po_number}").first
        expect(order).not_to be_nil

        expect(order.last_file_bucket).to eq "bucket"
        expect(order.last_file_path).to eq "key"
        expect(order.customer_order_number).to eq @po_number
        expect(order.importer).to eq @importer
        expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("#{@message_date} #{@message_time[0,2]}:#{@message_time[2,2]}").in_time_zone("UTC")
        expect(order.order_lines).to have(1).item

        l = order.order_lines.first
        expect(l.line_number).to eq @line_number.to_i
        expect(l.quantity).to eq BigDecimal.new(@quantity)
        expect(l.product.unique_identifier).to eq "#{@importer.fenix_customer_number}-#{@style}"
        expect(l.product.unit_of_measure).to eq @uom
        expect(l.product.name).to eq @style
        expect(l.product.get_custom_value(@part_no_cd).value).to eq @style
      end

      it "updates orders, adding new lines and eliminating old lines" do
        # Make sure we also attach to existing Products
        product = Product.create! importer: @importer, unique_identifier: "#{@importer.fenix_customer_number}-#{@style}"

        order = Order.new importer: @importer, customer_order_number: @po_number, order_number: "ABC"
        order.order_lines.build line_number: 1, product: product
        order.save!

        described_class.new.parse @xml_lambda.call

        order.reload
        expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("#{@message_date} #{@message_time[0,2]}:#{@message_time[2,2]}").in_time_zone("UTC")
        expect(order.order_lines).to have(1).item
        l = order.order_lines.first
        expect(l.line_number).to eq @line_number.to_i
        expect(l.product).to eq product
      end

      it "handles Club Monaco buyer" do
        @buyer_id = "0200011987"
        @importer = Factory(:company, fenix_customer_number: "866806458RM0001")

        described_class.new.parse @xml_lambda.call

        order = Order.where(order_number: "#{@importer.fenix_customer_number}-#{@po_number}").first
        expect(order).not_to be_nil
      end

      it "raises an error for unknown buyer ids" do
        @buyer_id = "unknown"
        expect{described_class.new.parse @xml_lambda.call}.to raise_error "Unknown Buyer ID #{@buyer_id} found in PO Number #{@po_number}.  If this is a new Buyer you must link this number to an Importer account."
      end

      it "raises an error if Importer cannot be found" do
        @importer.destroy

        expect{described_class.new.parse @xml_lambda.call}.to raise_error "Unable to find Fenix Importer for importer number #{@importer.fenix_customer_number}.  This account should not be missing."
      end

      it "raises an error if Part Number custom def is not found" do
        @part_no_cd.destroy

        expect{described_class.new.parse @xml_lambda.call}.to raise_error "Unable to find Part Number custom field for Product module."
      end
    end

    context :prepack_lines do
      before :each do
        @po_number = "PO"
        @merchandise_division = "MERCH"
        @buyer_id = "0200011989"
        @importer = Factory(:company, fenix_customer_number: "806167003RM0001")
        @xml_lambda = lambda do 
          <<-XML
<Orders>
  <MessageInformation>
    <MessageOrderNumber>#{@po_number}</MessageOrderNumber>
  </MessageInformation>
  <Parties>
    <NameAddress>
      <PartyID>
        <PartyIDType>BY</PartyIDType>
        <PartyIDValue>#{@buyer_id}</PartyIDValue>
      </PartyID>
    </NameAddress>
  </Parties>
  <Lines>
    <ProductLine>
      <SubLine>
        <ProductDescriptions>
          <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
          <ItemCharacteristicsDescriptionCode>#{@merchandise_division}</ItemCharacteristicsDescriptionCode>
        </ProductDescriptions>
      </SubLine>
    </ProductLine>
  </Lines>
</Orders>
XML
        end
      end

      it "should extract po and division code from subline and create a Data Cross Reference Record" do
        described_class.new.parse @xml_lambda.call

        r = DataCrossReference.first
        r.cross_reference_type.should eq DataCrossReference::RL_PO_TO_BRAND
        r.key.should eq @po_number
        r.value.should eq @merchandise_division
      end
    end
  end
end