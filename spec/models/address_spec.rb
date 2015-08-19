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

  describe "full_address" do
    before :each do
      @country = Factory(:country)
      @address = Address.new line_1: "Line 1", line_2: "Line 2", line_3: "Line 3", city: "City", state: "ST", postal_code: "1234N", country: @country
    end

    it "prints out full address on single line" do
      expect(@address.full_address).to eq "Line 1 Line 2 Line 3, City ST 1234N, #{@country.iso_code}"
    end

    it "handles missing address lines without printing extra spaces" do
      @address.assign_attributes line_2: " ", line_3: " "

      expect(@address.full_address).to eq "Line 1, City ST 1234N, #{@country.iso_code}"
    end

    it "handles missing address lines without priting leading spaces / comma" do
      @address.assign_attributes line_1: " ", line_2: " ", line_3: " "

      expect(@address.full_address).to eq "City ST 1234N, #{@country.iso_code}"
    end

    it "handles missing city lines without priting leading spaces" do
      @address.assign_attributes city: " ", state: "", postal_code: " "

      expect(@address.full_address).to eq "Line 1 Line 2 Line 3, #{@country.iso_code}"
    end

    it "prints nothing if everything is missing" do
      expect(Address.new.full_address).to eq ""
    end
  end
end