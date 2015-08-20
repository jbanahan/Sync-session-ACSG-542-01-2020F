require "spec_helper"

describe Address do
  context :address_hash do
    it "sets an address hash on save" do
      a = Factory(:address,name:'myname',line_1:'l1',line_2:'l2',city:'Jakarta')
      a.save!
      expect(a.address_hash).to eq Address.make_hash_key(a)
      prev_hash = a.address_hash
      a.update_attributes! name: "myname 2"
      expect(prev_hash).not_to eq a.address_hash

      # company id can change without the hash changing.
      prev_hash = a.address_hash
      a.update_attributes! company_id: -1
      expect(prev_hash).to eq a.address_hash
    end
    it "should ignore shipping flag" do
      a = Factory(:address,name:'myname',line_1:'l1',line_2:'l2',city:'Jakarta')
      a.save!
      a.shipping = !a.shipping
      a.save! #would raise exception if was included in immutability check
    end
  end
  describe :full_address do
    it "should render address with newlines" do
      a = Address.new(name:'Vandegrift',line_1:'234 Market St',line_2:'5th Floor',line_3:nil,city:'Philadelphia',state:'PA',postal_code:'19106',country:Factory(:country,iso_code:'US'))
      expected = "Vandegrift\n234 Market St\n5th Floor\nPhiladelphia, PA 19106 US"
      expect(a.full_address).to eq expected
    end
  end

  context :validations do
    it "should not allow destroy if in use" do
      a = Factory(:address)
      s = Factory(:shipment,ship_to_id:a.id)

      expect {a.destroy}.to_not change(Address,:count)

      expect(a.errors.full_messages).to eq ['Address cannot be deleted because it is still in use.']

    end
    it "should allow destory if not in use" do
      a = Factory(:address)

      expect {a.destroy}.to change(Address,:count).by(-1)
    end
  end

  # describe "full_address" do
  #   before :each do
  #     @country = Factory(:country)
  #     @address = Address.new line_1: "Line 1", line_2: "Line 2", line_3: "Line 3", city: "City", state: "ST", postal_code: "1234N", country: @country
  #   end

  #   it "prints out full address on single line" do
  #     expect(@address.full_address).to eq "Line 1 Line 2 Line 3, City ST 1234N, #{@country.iso_code}"
  #   end

  #   it "handles missing address lines without printing extra spaces" do
  #     @address.assign_attributes line_2: " ", line_3: " "

  #     expect(@address.full_address).to eq "Line 1, City ST 1234N, #{@country.iso_code}"
  #   end

  #   it "handles missing address lines without priting leading spaces / comma" do
  #     @address.assign_attributes line_1: " ", line_2: " ", line_3: " "

  #     expect(@address.full_address).to eq "City ST 1234N, #{@country.iso_code}"
  #   end

  #   it "handles missing city lines without priting leading spaces" do
  #     @address.assign_attributes city: " ", state: "", postal_code: " "

  #     expect(@address.full_address).to eq "Line 1 Line 2 Line 3, #{@country.iso_code}"
  #   end

  #   it "prints nothing if everything is missing" do
  #     expect(Address.new.full_address).to eq ""
  #   end
  # end

  describe :in_use do
    before :each do
      @c = Factory(:company)
      @a = Factory(:address,company:@c)
    end
    it "should return false if not in use" do
      expect(@a).to_not be_in_use      
    end
    it "should return true for address linked to custom value" do
      cd = Factory(:custom_definition, data_type: :integer, module_type: 'Company', is_address: true)
      @c.update_custom_value!(cd,@a.id)

      expect(@a).to be_in_use
    end
    it "should return true for address linked to shipment.ship_to" do
      Factory(:shipment,ship_to_id:@a.id)
      expect(@a).to be_in_use
    end
    it "should return true for address linked to shipment.ship_from" do
      Factory(:shipment,ship_from_id:@a.id)
      expect(@a).to be_in_use
    end
    it "should return true for address linked to delivery.ship_to" do
      Factory(:delivery,ship_to_id:@a.id)
      expect(@a).to be_in_use
    end
    it "should return true for address linked to delivery.ship_from" do
      Factory(:delivery,ship_from_id:@a.id)
      expect(@a).to be_in_use
    end
    it "should return true for address linked to order.ship_to" do
      Factory(:order,ship_to_id:@a.id)
      expect(@a).to be_in_use
    end
    it "should return true for address linked to sale.ship_to" do
      Factory(:sales_order,ship_to_id:@a.id)
      expect(@a).to be_in_use
    end
    it "should return true for linked product factories" do
      p = Factory(:product)
      p.factories << @a
      expect(@a).to be_in_use
    end

  end
end