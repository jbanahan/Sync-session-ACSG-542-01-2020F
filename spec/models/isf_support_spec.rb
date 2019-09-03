describe ISFSupport do
  describe "valid_isf?" do
    describe 'when the ISF is valid' do
      before :each do
        importer = with_customs_management_id(Factory(:importer, irs_number:'ashjdajdashdad'), 'asjhdajhdjasgd')
        consignee = Factory(:consignee, irs_number:'oijwofhiusfsdfhsdgf')
        @shipment = Factory(:shipment,
                            importer:importer,
                            consignee: consignee,
                            seller_address: Factory(:full_address),
                            buyer_address: Factory(:full_address),
                            ship_to_address: Factory(:full_address),
                            container_stuffing_address: Factory(:full_address),
                            consolidator_address: Factory(:full_address),
                            house_bill_of_lading:'this is a bill'
        )
        Factory(:shipment_line, shipment:@shipment, manufacturer_address:Factory(:full_address))
        Factory(:shipment_line, shipment:@shipment, manufacturer_address:Factory(:full_address))
        allow_any_instance_of(ShipmentLine).to receive(:country_of_origin).and_return('Greenland')
        allow_any_instance_of(ShipmentLine).to receive(:us_hts_number).and_return('123456789')
      end

      it 'works at all' do
        expect(@shipment.valid_isf?).to eq true
      end
    end

    describe "when the ISF is not valid" do
      it "returns false" do
        # By default a shipment isn't going to be valid, missing Importers, parties, etc.
        expect(Factory(:shipment).valid_isf?).to be_falsey
      end
    end
  end
  
  describe "validate_isf" do
    describe 'when the ISF is not valid' do
      describe "when the importer doesn't have an kewill customs number" do
        before :each do
          importer = Factory(:importer, irs_number:'ashjdajdashdad')
          @shipment = Factory(:shipment, importer:importer)
          @shipment.validate_isf
        end

        it 'is invalid' do
          expect(@shipment.errors[:importer]).to include('must have an Alliance Customer Number')
        end
      end

      describe "when the importer doesn't have an IRS number" do
        before :each do
          importer = Factory(:importer)
          @shipment = Factory(:shipment, importer:importer)
          @shipment.validate_isf
        end

        it 'is invalid' do
          expect(@shipment.errors[:importer]).to include("Importer IRS Number can't be blank")
        end
      end

      describe "when the consignee doesn't have an IRS number" do
        before :each do
          consignee = Factory(:consignee)
          @shipment = Factory(:shipment, consignee:consignee)
          @shipment.validate_isf
        end

        it 'is invalid' do
          expect(@shipment.errors[:consignee]).to include("Consignee IRS Number can't be blank")
        end
      end

      describe 'when the shipment is missing both bill of lading numbers' do
        before :each do
          @shipment = Factory :shipment, master_bill_of_lading:nil, house_bill_of_lading:nil
          @shipment.validate_isf
        end

        it 'is invalid' do
          expect(@shipment.errors[:base]).to include("Shipment must have either a Master or House Bill of Lading number")
        end

      end

      describe 'when one of the shipment lines is missing a manufacturer address' do
        before :each do
          @shipment = Factory :shipment
          Factory :shipment_line, shipment:@shipment, manufacturer_address:Factory(:full_address)
          Factory :shipment_line, shipment:@shipment, manufacturer_address:Factory(:full_address)
          @no_address_line = Factory :shipment_line, shipment:@shipment, manufacturer_address_id:nil
          @shipment.validate_isf
        end

        it 'is invalid' do
          expect(@shipment.errors[:base]).to include("Shipment Line #{@no_address_line.line_number} Manufacturer address is missing")
        end
      end

      describe "when manufacturer address is missing required fields" do
        before :each do
          @shipment = Factory :shipment
          @line = Factory :shipment_line, shipment:@shipment, manufacturer_address:Factory(:address)
          @line.manufacturer_address.update_attributes! name: "", country: nil
        end

        it "is invalid" do
          @shipment.validate_isf
          expect(@shipment.errors[:base]).to include("Shipment Line #{@line.line_number} Manufacturer address is missing required fields: Name, Address 1, City, State, Postal Code, Country")
        end
      end

      describe "when parties are missing address fields" do
        before :each do
          importer = with_customs_management_id(Factory(:importer, irs_number:'ashjdajdashdad'), 'asjhdajhdjasgd')
          consignee = Factory(:consignee, irs_number:'oijwofhiusfsdfhsdgf')
          @shipment = Factory(:shipment,
                              importer:importer,
                              consignee: consignee,
                              seller_address: Factory(:blank_address),
                              buyer_address: Factory(:blank_address),
                              ship_to_address: Factory(:blank_address),
                              container_stuffing_address: Factory(:blank_address),
                              consolidator_address: Factory(:blank_address),
                              house_bill_of_lading:'this is a bill')
        end

        it "is invalid" do
          @shipment.validate_isf
          expect(@shipment.errors.full_messages).to include("Seller address is missing required fields: Name, Address 1, City, State, Postal Code, Country")
          expect(@shipment.errors.full_messages).to include("Buyer address is missing required fields: Name, Address 1, City, State, Postal Code, Country")
          expect(@shipment.errors.full_messages).to include("Ship to address is missing required fields: Name, Address 1, City, State, Postal Code, Country")
          expect(@shipment.errors.full_messages).to include("Container stuffing address is missing required fields: Name, Address 1, City, State, Postal Code, Country")
          expect(@shipment.errors.full_messages).to include("Consolidator address is missing required fields: Name, Address 1, City, State, Postal Code, Country")
        end
      end
    end

    describe "when parties are missing addresses" do
      before :each do
        importer = Factory(:importer, irs_number:'ashjdajdashdad')
        consignee = Factory(:consignee, irs_number:'oijwofhiusfsdfhsdgf')
        @shipment = Factory(:shipment,
                            importer:importer,
                            consignee: consignee,
                            house_bill_of_lading:'this is a bill')
      end

      it "is invalid" do
        @shipment.validate_isf
        expect(@shipment.errors.full_messages).to include("Seller address must be present")
        expect(@shipment.errors.full_messages).to include("Buyer address must be present")
        expect(@shipment.errors.full_messages).to include("Ship to address must be present")
        expect(@shipment.errors.full_messages).to include("Container stuffing address must be present")
        expect(@shipment.errors.full_messages).to include("Consolidator address must be present")
      end
    end

    describe "when Country of Origin or HTS number is missing from a shipment line" do 
      before :each do
        @shipment = Factory(:shipment)
      end

      it "is invalid when country of origin is missing from shipment line" do
        line_1 = Factory(:shipment_line, shipment:@shipment)
        allow(line_1).to receive(:us_hts_number).and_return "123"

        @shipment.validate_isf
        expect(@shipment.errors.full_messages).to include("All shipment lines must have a Country of Origin and HTS Number")
      end

      it "is invalid when hts is missing" do
        line_1 = Factory(:shipment_line, shipment:@shipment)
        allow(line_1).to receive(:country_of_origin).and_return "CN"

        @shipment.validate_isf
        expect(@shipment.errors.full_messages).to include("All shipment lines must have a Country of Origin and HTS Number")
      end
    end
  end
end