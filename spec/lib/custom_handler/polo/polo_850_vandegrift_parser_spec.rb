require 'spec_helper'

describe OpenChain::CustomHandler::Polo::Polo850VandegriftParser do

  describe :integration_folder do
    it "should use the correct folder" do
      described_class.integration_folder.should eq "/opt/wftpserver/ftproot/www-vfitrack-net/_polo_850"
    end
  end

  describe :parse do
    context :standard_line_type do
      before :each do
        @po_number = "PO"
        @merchandise_division = "MERCH"
        @xml_lambda = lambda do 
          <<-XML
<Orders>
  <MessageInformation>
    <MessageOrderNumber>#{@po_number}</MessageOrderNumber>
  </MessageInformation>
  <Lines>
    <ProductLine>
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
        described_class.parse @xml_lambda.call

        r = DataCrossReference.first
        r.cross_reference_type.should eq DataCrossReference::RL_PO_TO_BRAND
        r.key.should eq @po_number
        r.value.should eq @merchandise_division
      end

      it "should update existing cross reference records" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_PO_TO_BRAND, key: @po_number, value: "some_other_value"

        described_class.parse @xml_lambda.call

        r = DataCrossReference.first
        r.value.should eq @merchandise_division
      end
    end

    context :prepack_lines do
      before :each do
        @po_number = "PO"
        @merchandise_division = "MERCH"
        @xml_lambda = lambda do 
          <<-XML
<Orders>
  <MessageInformation>
    <MessageOrderNumber>#{@po_number}</MessageOrderNumber>
  </MessageInformation>
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
        described_class.parse @xml_lambda.call

        r = DataCrossReference.first
        r.cross_reference_type.should eq DataCrossReference::RL_PO_TO_BRAND
        r.key.should eq @po_number
        r.value.should eq @merchandise_division
      end
    end
  end
end