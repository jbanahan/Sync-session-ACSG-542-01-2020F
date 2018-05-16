require "spec_helper"

describe Address do

  describe '#can_view?' do
    before :each do
      @a = Factory(:address)
      @c = @a.company
    end
    it "should be visible if linked to my company" do
      u = Factory(:user,company:@c)
      expect(@a.can_view?(u)).to be_truthy
    end
    it "should be visible if linked to a company I'm linked to" do
      u = Factory(:user)
      u.company.linked_companies << @c
      expect(@a.can_view?(u)).to be_truthy
    end
    it "should not be visible if not linked to my company or a company I'm linked to" do
      u = Factory(:user)
      expect(@a.can_view?(u)).to be_falsey
    end
  end

  context "address_hash" do
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
    it "should render address with newlines" do
      a = Address.new(name:'Vandegrift',line_1:'234 Market St',line_2:'5th Floor',line_3:nil,city:'Philadelphia',state:'PA',postal_code:'19106',country:Factory(:country,iso_code:'US'))
      expected = "Vandegrift\n234 Market St\n5th Floor\nPhiladelphia, PA 19106 US"
      expect(a.full_address).to eq expected
    end
  end

  describe "full_address_array" do
    let (:address) {
      Address.new(name:'Vandegrift',line_1:'234 Market St',line_2:'5th Floor',line_3:nil,city:'Philadelphia',state:'PA',postal_code:'19106',country:Factory(:country,iso_code:'US'))
    }

    it "renders full address fields as an array of lines" do
      expect(address.full_address_array).to eq ["Vandegrift", "234 Market St", "5th Floor", "Philadelphia, PA 19106 US"]
    end

    it "skips address name if instructed" do
      expect(address.full_address_array(skip_name: true)).to eq ["234 Market St", "5th Floor", "Philadelphia, PA 19106 US"]
    end

    it "skips blank address lines" do
      address.line_2 = "  "
      expect(address.full_address_array(skip_name: true)).to eq ["234 Market St", "Philadelphia, PA 19106 US"]
    end

    it "handles missing city" do
      address.city = ""
      expect(address.full_address_array.last).to eq "PA 19106 US"
    end

    it "handles missing country" do
      address.country = nil
      expect(address.full_address_array.last).to eq "Philadelphia, PA 19106"
    end
  end

  context "validations" do
    it "should not allow destroy if in use" do
      a = Factory(:address)
      Factory(:shipment,ship_to_id:a.id)

      expect {a.destroy}.to_not change(Address,:count)

      expect(a.errors.full_messages).to eq ['Address cannot be deleted because it is still in use.']

    end
    it "should allow destory if not in use" do
      a = Factory(:address)

      expect {a.destroy}.to change(Address,:count).by(-1)
    end
  end


  describe "in_use" do
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

  describe "update_kewill_addresses" do
    subject { described_class }
    let! (:country) { Country.where(iso_code: "US").first_or_create! }
    let (:address_row) {
      ["CUSTNO", "Customer Name", "00001", "Address Name", "Address 1", "Address 2", "City", "State", "Postal", "US"]
    }

    it "receives an address array, generates a new company record and adds the address" do
      subject.update_kewill_addresses [address_row]

      c = Company.where(alliance_customer_number: "CUSTNO", importer: true, name: "Customer Name").first
      expect(c).not_to be_nil

      address = c.addresses.first
      expect(address).not_to be_nil
      expect(address.system_code).to eq "1"
      expect(address.name).to eq "Address Name"
      expect(address.line_1).to eq "Address 1"
      expect(address.line_2).to eq "Address 2"
      expect(address.city).to eq "City"
      expect(address.state).to eq "State"
      expect(address.postal_code).to eq "Postal"
      expect(address.country).to eq country
    end

    it "updates an existing address" do
      c = Company.create! alliance_customer_number: "CUSTNO", name: "Cust"
      address = c.addresses.create! system_code: "1"

      subject.update_kewill_addresses [address_row]

      address.reload
      expect(address.name).to eq "Address Name"
      expect(address.line_1).to eq "Address 1"
      expect(address.line_2).to eq "Address 2"
      expect(address.city).to eq "City"
      expect(address.state).to eq "State"
      expect(address.postal_code).to eq "Postal"
      expect(address.country).to eq country
    end
  end

  describe "make_hash_key" do
    let (:a) {
      Address.new system_code: "Code", name: "Address", line_1: "Line 1", line_2: "Line 2", line_3: "Line 3", city: "City", state: "State", postal_code: "Postal", country_id: 1, address_type: "Type"
    }
    subject { described_class }

    it "generates an md5 hash from name/address/city/state/postal_code/country/system_code" do
      expect(subject.make_hash_key a).to eq "be583b5452e3788d27691921332fbca2"
    end

    it "generates a different hash key if address type is removed" do
      a.address_type = nil
      expect(subject.make_hash_key a).to eq "46a691c170e28e29b4798c689601e85b"
    end

    it "passes expected values to hexdigest" do
      expect(Digest::MD5).to receive(:hexdigest).with("#{a.name}#{a.line_1}#{a.line_2}#{a.line_3}#{a.city}#{a.state}#{a.postal_code}#{a.country_id}#{a.system_code}#{a.address_type}")
      subject.make_hash_key a
    end
  end
end
