require 'spec_helper'

describe ISFSupport do
  describe :valid_isf? do
    describe 'when the ISF is valid' do
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
                            house_bill_of_lading:'this is a bill'
        )
        Factory(:shipment_line, shipment:@shipment)
        ShipmentLine.any_instance.stub(:country_of_origin).and_return('Greenland')
        ShipmentLine.any_instance.stub(:us_hts_number).and_return('123456789')
      end

      it 'works at all' do
        expect(@shipment.valid_isf?).to eq true
      end
    end

    describe 'when the ISF is not valid' do
      describe 'when the importer doesn\'t have an alliance number' do
        before :each do
          importer = Factory(:importer, irs_number:'ashjdajdashdad')
          @shipment = Factory(:shipment, importer:importer)
          @shipment.validate_isf!
        end

        it 'is invalid' do
          expect(@shipment.errors[:importer]).to include('must have an Alliance Customer Number')
        end
      end

      describe 'when the importer doesn\'t have an IRS number' do
        before :each do
          importer = Factory(:importer, alliance_customer_number:'ashjdajdashdad')
          @shipment = Factory(:shipment, importer:importer)
          @shipment.validate_isf!
        end

        it 'is invalid' do
          expect(@shipment.errors[:importer]).to include("IRS Number can't be blank")
        end
      end

      describe 'when the consignee doesn\'t have an IRS number' do
        before :each do
          consignee = Factory(:consignee, alliance_customer_number:'ashjdajdashdad')
          @shipment = Factory(:shipment, consignee:consignee)
          @shipment.validate_isf!
        end

        it 'is invalid' do
          expect(@shipment.errors[:consignee]).to include("IRS Number can't be blank")
        end
      end

      describe 'when the shipment is missing both bill of lading numbers' do
        before :each do
          @shipment = Factory :shipment, master_bill_of_lading:nil, house_bill_of_lading:nil
          @shipment.validate_isf!
        end

        it 'is invalid' do
          expect(@shipment.errors[:base]).to include("Shipment must have either a Master or House Bill of Lading number")
        end

      end
    end
  end
end