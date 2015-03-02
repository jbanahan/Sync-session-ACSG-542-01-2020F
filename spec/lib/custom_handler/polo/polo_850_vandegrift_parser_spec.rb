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
        @cdefs = described_class.prep_custom_definitions [:ord_invoicing_system, :prod_part_number, :ord_line_ex_factory_date, :ord_division]
        @po_type = ""
        @po_number = "PO"
        @message_date = "2014-01-01"
        @message_time = "1200"
        @line_number = "00010"
        @style = "STYLE"
        @uom = "UOM"
        @quantity = "10"
        @buyer_id = "0200011989"
        @ref_type = "9V"
        @ref_value = "TC"
        @primary_ex_factory = '2014-02-01'
        @updated_ex_factory = '2014-03-01'

        @po_lines = []
        @po_lines << {
          line_number: "00010",
          style: "STYLE",
          uom: "UOM",
          quantity: "10",
          merchandise_division_numeric: "200",
          merchandise_division: "MERCH",
          primary_ex_factory: '2014-02-01',
          updated_ex_factory: '2014-03-01'
        }

        @importer = Factory(:company, fenix_customer_number: "806167003RM0001")

        @xml_lambda = lambda do
          xml = "<Orders>
                  <MessageInformation>
                    <MessageOrderNumber>#{@po_number}</MessageOrderNumber>
                    <MessageDate>#{@message_date}</MessageDate>
                    <MessageTime>#{@message_time}</MessageTime>
                    <OrderChangeType>#{@po_type}</OrderChangeType>
                  </MessageInformation>
                  <MessageReferences>
                    <References>
                      <ReferenceType>#{@ref_type}</ReferenceType>
                      <ReferenceValue>#{@ref_value}</ReferenceValue>
                    </References>
                  </MessageReferences>
                  <Parties>
                    <NameAddress>
                      <PartyID>
                        <PartyIDType>BY</PartyIDType>
                        <PartyIDValue>#{@buyer_id}</PartyIDValue>
                      </PartyID>
                    </NameAddress>
                  </Parties>
                  <Lines>
                "
        @po_lines.each do |line|
          xml += "<ProductLine>
                    <PositionNumber>#{line[:line_number]}</PositionNumber>
                    <ProductDetails3>
                      <ProductID>
                        <ProductIDValue>#{line[:style]}</ProductIDValue>
                      </ProductID>
                    </ProductDetails3>
                    <ProductQuantityDetails>
                      <ProductQuantityUOM>#{line[:uom]}</ProductQuantityUOM>
                      <QuantityOrdered>#{line[:quantity]}</QuantityOrdered>
                    </ProductQuantityDetails>
                    <ProductDescriptions>
                      <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
                      <ItemCharacteristicsDescriptionCode>#{line[:merchandise_division_numeric]}</ItemCharacteristicsDescriptionCode>
                      <ItemDescription>#{line[:merchandise_division]}</ItemDescription>
                    </ProductDescriptions>
                    <ProductDates>
                      <DatesTimes>
                        <DateTimeType>065</DateTimeType>
                        <Date>#{line[:primary_ex_factory]}</Date>
                      </DatesTimes>
                      <DatesTimes>
                        <DateTimeType>118</DateTimeType>
                        <Date>#{line[:updated_ex_factory]}</Date>
                      </DatesTimes>
                    </ProductDates>
                  </ProductLine>"
        end
        xml += "</Lines>
            </Orders>"
        end
      end

      it "should extract po and division code and create a Data Cross Reference Record" do
        described_class.new.parse @xml_lambda.call

        r = DataCrossReference.first
        r.cross_reference_type.should eq DataCrossReference::RL_PO_TO_BRAND
        r.key.should eq @po_number
        r.value.should eq @po_lines.first[:merchandise_division_numeric]
      end

      it "should update existing cross reference records" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_PO_TO_BRAND, key: @po_number, value: "some_other_value"

        described_class.new.parse @xml_lambda.call

        r = DataCrossReference.first
        r.value.should eq @po_lines.first[:merchandise_division_numeric]
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
        expect(order.get_custom_value(@cdefs[:ord_invoicing_system]).value).to eq "Tradecard"
        expect(order.get_custom_value(@cdefs[:ord_division]).value).to eq @po_lines.first[:merchandise_division]
        expect(order.order_lines).to have(1).item

        l = order.order_lines.first
        line = @po_lines.first
        expect(l.line_number).to eq line[:line_number].to_i
        expect(l.quantity).to eq BigDecimal.new(line[:quantity])
        expect(l.product.unique_identifier).to eq "#{@importer.fenix_customer_number}-#{line[:style]}"
        expect(l.product.unit_of_measure).to eq line[:uom]
        expect(l.product.name).to eq line[:style]
        expect(l.product.get_custom_value(@cdefs[:prod_part_number]).value).to eq line[:style]
        expect(l.get_custom_value(@cdefs[:ord_line_ex_factory_date]).value).to eq Date.new(2014, 3, 1)
      end

      it "updates orders, adding new lines, updating existing lines, and eliminating old lines" do
        # Make sure we also attach to existing Products
        first_product = @po_lines.first
        product = Product.create! importer: @importer, unique_identifier: "#{@importer.fenix_customer_number}-#{first_product[:style]}"

        order = Order.new importer: @importer, customer_order_number: @po_number, order_number: "ABC"
        updated_line = order.order_lines.build line_number: first_product[:line_number], product: product
        order.save!

        removed_product = Product.create! importer: @importer, unique_identifier: "#{@importer.fenix_customer_number}-RANDOMSTYLE"
        removed_line = order.order_lines.build line_number: 1, product: product

        @po_lines <<  {
          line_number: "00020",
          style: "STYLE-2",
          uom: "UOM",
          quantity: "10",
          merchandise_division: "MERCH",
          primary_ex_factory: '2014-02-01',
          updated_ex_factory: '2014-03-01'
        }

        described_class.new.parse @xml_lambda.call

        order.reload
        expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("#{@message_date} #{@message_time[0,2]}:#{@message_time[2,2]}").in_time_zone("UTC")
        expect(order.order_lines.length).to eq 2
        l = order.order_lines.first
        expect(l.id).to eq updated_line.id
        expect(l.line_number).to eq first_product[:line_number].to_i
        expect(l.product).to eq product
        expect(l.get_custom_value(@cdefs[:ord_line_ex_factory_date]).value).to eq Date.new(2014, 3, 1)

        l = order.order_lines.second
        expect(l.line_number).to eq @po_lines.second[:line_number].to_i
        expect(l.product.unique_identifier).to eq "#{@importer.fenix_customer_number}-#{@po_lines.second[:style]}"

        expect(order.order_lines.find {|l| l.id == removed_line.id}).to be_nil
      end

      it "uses primary ex factory if that's the only ex-factory value present" do
        @po_lines.first[:updated_ex_factory] = "notadate"

        described_class.new.parse @xml_lambda.call, bucket: "bucket", key: "key"

        order = Order.where(order_number: "#{@importer.fenix_customer_number}-#{@po_number}").first
        expect(order).not_to be_nil
        l = order.order_lines.first
        expect(l.get_custom_value(@cdefs[:ord_line_ex_factory_date]).value).to eq Date.new(2014, 2, 1)
      end

      it "handles Club Monaco buyer" do
        @buyer_id = "0200011987"
        @importer = Factory(:company, fenix_customer_number: "866806458RM0001")

        described_class.new.parse @xml_lambda.call

        order = Order.where(order_number: "#{@importer.fenix_customer_number}-#{@po_number}").first
        expect(order).not_to be_nil
      end

      it "handles TradeCard First Sale invoicing system values" do
        @ref_value = 'TCF'
        described_class.new.parse @xml_lambda.call

        order = Order.where(order_number: "#{@importer.fenix_customer_number}-#{@po_number}").first
        expect(order.get_custom_value(@cdefs[:ord_invoicing_system]).value).to eq "Tradecard"
      end

      it "raises an error for unknown buyer ids" do
        @buyer_id = "unknown"
        expect{described_class.new.parse @xml_lambda.call}.to raise_error "Unknown Buyer ID #{@buyer_id} found in PO Number #{@po_number}.  If this is a new Buyer you must link this number to an Importer account."
      end

      it "raises an error if Importer cannot be found" do
        @importer.destroy

        expect{described_class.new.parse @xml_lambda.call}.to raise_error "Unable to find Fenix Importer for importer number #{@importer.fenix_customer_number}.  This account should not be missing."
      end
    end

    context :prepack_lines do
      before :each do
        @po_number = "PO"
        @merchandise_division = "MERCH"
        @buyer_id = "0200011989"
        @importer = Factory(:company, fenix_customer_number: "806167003RM0001")
        @style = "Style"
        @merchandise_division_desc = "MERCH"
        @cdefs = described_class.prep_custom_definitions [:ord_division]
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
      <PositionNumber>1</PositionNumber>
      <ProductDetails3>
        <ProductID>
          <ProductIDValue>#{@style}</ProductIDValue>
        </ProductID>
      </ProductDetails3>
      <SubLine>
        <ProductDescriptions>
          <ItemCharacteristicsDescriptionCodeDesc>MDV</ItemCharacteristicsDescriptionCodeDesc>
          <ItemCharacteristicsDescriptionCode>#{@merchandise_division}</ItemCharacteristicsDescriptionCode>
          <ItemDescription>#{@merchandise_division_desc}</ItemDescription>
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

        order = Order.where(order_number: "#{@importer.fenix_customer_number}-#{@po_number}").first
        expect(order).not_to be_nil
        expect(order.get_custom_value(@cdefs[:ord_division]).value).to eq @merchandise_division_desc
      end
    end
  end
end