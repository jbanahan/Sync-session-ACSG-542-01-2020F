require 'test_helper'

class OrderTest < ActiveSupport::TestCase

  test "master company user can view" do
    ord = Order.find(1)
    user = User.find(1)
    assert user.company.master, "Setup check failed: User 1 should be master."
    assert ord.can_view?(user), "Master company user cannot view order."
  end
  
  test "vendor can view" do
    ord = Order.find(1)
    assert ord.vendor_id = 2, "Setup check: Order 1's vendor should be company 2"
    user = enable_all_personal_permissions User.find(2)
    assert user.company_id = 2, "Setup check: User 2 should be for company 2"
    assert user.company.vendor, "Setup check: Company should be vendor"
    assert ord.can_view?(user), "Vendor user cannot view order for own company."
  end
  
  test "vendor cannot view other vendor's order" do
    ord = Order.find(1)
    assert ord.vendor_id = 2, "Setup check: Order 1's vendor should be company 2"
    user = enable_all_personal_permissions User.find(3)
    assert user.company_id = 3, "Setup check: User 3 should be for company 3"
    assert user.company.vendor, "Setup check: Company should be vendor"
    assert !ord.can_view?(user), "Vendor user can view order for different company."
  end
  
  test "related shipments" do
    ord = Order.create!(:order_number=>"related_shipments",:vendor => companies(:vendor))
    oline = ord.order_lines.create!(:product=>ord.vendor.vendor_products.first)
    ps = oline.piece_sets.create!(:quantity=>5)
    shp = Shipment.create!(:reference=>"related_shipments",:vendor_id => ord.vendor_id)
    sline = shp.shipment_lines.create!(:product=>oline.product)
    ps.shipment_line = sline
    ps.save!
    ps2 = oline.piece_sets.create!(:quantity=>3)
    shp2 = Shipment.create!(:reference=>"related_shipments2",:vendor_id=>ord.vendor_id)
    sline2 = shp2.shipment_lines.create!(:product=>oline.product)
    ps2.shipment_line = sline2
    ps2.save!
    
    r = ord.related_shipments.to_a
    assert r.length ==2, "should be two related shipments, there are "+r.length.to_s
    [shp,shp2].each do |s|
      assert r.include?(shp), "Did not find shipment with reference #{shp.reference}, #{r.to_s}"
    end
  end
  
  test "find by vendor" do
    r = Order.find_by_vendor(Company.find(2))
    assert r.length == 2, "should be two orders for vendor 2, there are "+r.length.to_s
    found_1 = false
    found_2 = false
    r.each do |s|
      if s.id == 1
        found_1 = true
      elsif s.id == 2
        found_2 = true
      end
    end
    assert found_1, "did not find order 1"
    assert found_2, "did not find order 2"
  end
  
  test "find same" do
    source = Order.create!(:order_number=>'123456zb',:vendor_id=>companies(:vendor).id)
    o = Order.new
    o.order_number = source.order_number
    found = o.find_same
    assert found == source, "Should have found source order."
    o.order_number = 123456
    assert o.find_same.nil?, "Should not find an order"
  end
  
  test "shallow merge into" do
    base_attribs = {:order_number => "base_ord_num",
        :order_date => Date.new(2010,11,1),
        :division_id => 1,
        :vendor_id => 2}
    base = Order.new(base_attribs)
    newer_attribs = {:order_number => "new_ord_num",
      :order_date => Date.new(2011,3,2),
      :division_id => 3,
      :vendor_id => 4}
    newer = Order.new(newer_attribs)
    base.save!
    newer.save!
    newer.updated_at = DateTime.new(2012,3,9)
    newer.created_at = DateTime.new(2007,5,2)
    target_attribs = {'order_number' => base.order_number,
      'order_date' => newer.order_date,
      'division_id' => newer.division_id,
      'vendor_id' => newer.vendor_id,
      'updated_at' => base.updated_at,
      'created_at' => base.created_at,
      'id' => base.id
    } 
    base.shallow_merge_into(newer)
    target_attribs.each_key { |k|
      assert target_attribs[k] == base.attributes[k], "Merged key (#{k}) not equal ('#{target_attribs[k]}' & '#{base.attributes[k]}')"
    }
  end
  
  test "locked" do
    vendor = Company.find(2)
    vendor.locked = true
    vendor.save!
    o = Order.find(1)
    assert o.locked?, "Order should be locked since vendor was locked."
  end
  
  test "custom_field_definitions" do
    o = Order.new
    cf = CustomDefinition.create!(:label=>"x", :data_type=>"string", :module_type=>"Order")
    assert o.custom_definitions.include?(cf), "Didn't find definition." 
  end
  
end
