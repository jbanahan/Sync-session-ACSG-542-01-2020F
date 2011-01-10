require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "make unpacked piece sets" do
    ord = Order.find(1)
    sets = ord.make_unpacked_piece_sets
    assert sets.length == 3, "Should be 3 sets returned"
    found_one = false
    found_two = false
    found_three = false
    sets.each do |s|
      if s.order_line_id == 1
        assert s.quantity == 4
        found_one = true
      elsif s.order_line_id == 2
        assert s.quantity = 9.99
        found_two = true
      elsif s.order_line_id == 3
        assert s.quantity = 2
        found_three = true 
      else
        assert false, "PieceSet with unexpected order line: " + s.order_line_id
      end
    end
    assert found_one && found_two && found_three, "Did not find all three piece sets."
  end
  
  test "make unpacked piece sets for full order" do
    ord = Order.find(1).clone
    ord.save!
    Order.find(1).order_lines.each do |ln|
      c = ln.clone
      c.order_id = ord.id
      c.save!
    end
    sets = ord.make_unpacked_piece_sets #to fill order
    sets.each do |s|
      s.shipment_id = 1
      s.save!
    end
    sets = ord.make_unpacked_piece_sets
    assert sets.length == 3, "Set count should have been 3, was #{sets.length}."
    sets.each do |s|
      assert s.quantity == 0, "Quantity should have been 0, was #{s.quantity}."
    end
  end
  
  test "master company user can view" do
    ord = Order.find(1)
    user = User.find(1)
    assert user.company.master, "Setup check failed: User 1 should be master."
    assert ord.can_view?(user), "Master company user cannot view order."
  end
  
  test "vendor can view" do
    ord = Order.find(1)
    assert ord.vendor_id = 2, "Setup check: Order 1's vendor should be company 2"
    user = User.find(2)
    assert user.company_id = 2, "Setup check: User 2 should be for company 2"
    assert user.company.vendor, "Setup check: Company should be vendor"
    assert ord.can_view?(user), "Vendor user cannot view order for own company."
  end
  
  test "vendor cannot view other vendor's order" do
    ord = Order.find(1)
    assert ord.vendor_id = 2, "Setup check: Order 1's vendor should be company 2"
    user = User.find(3)
    assert user.company_id = 3, "Setup check: User 3 should be for company 3"
    assert user.company.vendor, "Setup check: Company should be vendor"
    assert !ord.can_view?(user), "Vendor user can view order for different company."
  end
  
  test "related shipments" do
    ord = Order.find(1)
    r = ord.related_shipments
    assert r.length ==2, "should be two related shipments, there are "+r.length.to_s
    found_1 = false
    found_2 = false
    r.each do |s|
      if s.id == 1
        found_1 = true
      elsif s.id == 2
        found_2 = true
      end
    end
    assert found_1, "did not find shipment 1"
    assert found_2, "did not find shipment 2"
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
    source = Order.find(1)
    o = Order.new
    o.order_number = source.order_number
    found = o.find_same
    assert found == source, "Should have found source order."
    o.order_number = "don't find this"
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
