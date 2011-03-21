require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "can_view" do
    u = User.find(1)
    assert Product.find(1).can_view?(u), "Master user can't view product."
    u = User.find(2)
    assert Product.find(1).can_view?(u), "Vendor can't view own product."
    assert !Product.find(2).can_view?(u), "Vendor can view other's product."
    u = User.find(4)
    assert !Product.find(1).can_view?(u), "Carrier can view product."
    assert !Product.find(2).can_view?(u), "Carrier can view product."
  end
  
  test "can_edit" do
    u = User.find(1)
    assert Product.find(1).can_edit?(u), "Master user can't edit product."
    u = User.find(2)
    assert !Product.find(1).can_edit?(u), "Vendor can edit own product."
    assert !Product.find(2).can_edit?(u), "Vendor can edit other's product."
    u = User.find(4)
    assert !Product.find(1).can_edit?(u), "Carrier can edit product."
    assert !Product.find(2).can_edit?(u), "Carrier can edit product."
  end
  
  test "find_can_view" do
    u = User.find(1)
    assert Product.find_can_view(u) == Product.all, "Master didn't find all."
    u = User.find(2)
    found = Product.find_can_view(u)
    assert found.length>0 && found.include?(Product.find(1)), "Vendor didn't find product 1."
    u = User.find(4)
    found = Product.find_can_view(u)
    assert found.length==0
  end
  
  test "shallow merge into" do
    base_attribs = {
      :unique_identifier => "ui",
      :name => "bname",
      :vendor_id => 2,
      :division_id => 1
    }
    base = Product.new(base_attribs)
    newer_attribs = {
      :unique_identifier => "to be ignored",
      :name => "nname",
      :vendor_id => 3,
      :division_id => 2
    }
    newer = Product.new(newer_attribs)
    base.save!
    newer.save!
    newer.updated_at = DateTime.new(2012,3,9)
    newer.created_at = DateTime.new(2007,5,2)
    target_attribs = {'unique_identifier' => base.unique_identifier,
      'name' => newer.name,
      'division_id' => newer.division_id,
      'vendor_id' => base.vendor_id,
      'updated_at' => base.updated_at,
      'created_at' => base.created_at,
      'id' => base.id
    } 
    base.shallow_merge_into(newer)
    target_attribs.each_key { |k|
      assert target_attribs[k] == base.attributes[k], "Merged key (#{k}) not equal ('#{target_attribs[k]}' & '#{base.attributes[k]}')"
    }
  end
  
  test "has orders?" do
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_orders?, "Should not find orders."
    Order.create!(:order_number=>"phas",:vendor=>p.vendor).order_lines.create!(:product=>p)
    p.reload
    assert p.has_orders?, "Should find orders."
  end
  
  test "has shipments" do
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_shipments?, "Should not find shipments."
    Shipment.create!(:reference=>"phas",:vendor=>p.vendor).shipment_lines.create!(:product=>p)
    p.reload
    assert p.has_shipments?, "Should find shipments."
  end
  
  test "has deliveries" do 
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_deliveries?, "Should not find deliveries."
    Delivery.create!(:reference=>"phas",:customer=>companies(:customer)).delivery_lines.create!(:product=>p)
    p.reload
    assert p.has_deliveries?, "Should find deliveries."
  end
  
  test "has sales orders" do
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_sales_orders?, "Should not find sales orders"
    SalesOrder.create!(:order_number=>"phas",:customer=>companies(:customer)).sales_order_lines.create!(:product=>p)
    p.reload
    assert p.has_sales_orders?, "Should find sales orders"
  end
  
  test "set status" do
    sr = status_rules(:ProductIsApproved)
    a = products(:ApprovedStatusNotSet)
    a.status_rule_id = nil
    a.set_status
    assert a.status_rule_id == sr.id, "Status rule id should be #{sr.id}, was #{a.status_rule_id}"
    assert a.status_name == sr.name, "Status name should be #{sr.name}, was #{a.status_name}"
  end

  
end
