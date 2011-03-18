require 'test_helper'

class ShipmentTest < ActiveSupport::TestCase
 
  
  test "can view" do
    s = Shipment.find(2) #carrier 5, vendor 3
    assert s.can_view?(User.find(5)), "Matching carrier failed."
    assert !s.can_view?(User.find(4)), "Non-matching carrier failed."
    assert s.can_view?(User.find(3)), "Matching vendor failed."
    assert !s.can_view?(User.find(2)), "Non-matching vendor failed."
    assert s.can_view?(User.find(1)), "Master user failed."
  end

  test "simple receive" do
    quantity = 50
    vendor = companies(:vendor)
    product = vendor.vendor_products.first
    o = Order.create!(:vendor_id=>vendor.id)
    ord_line = o.order_lines.create!(:product_id => product.id,:line_number => 1,:ordered_qty => quantity)

    s = Shipment.create!(:vendor_id=>vendor.id)
    base_ps = s.piece_sets.build(:order_line_id => ord_line.id, :quantity => quantity, :product_id => product.id)
    base_ps.save!
    inv_in = s.receive({ord_line=>quantity})

    assert !inv_in.id.nil?, "Inventory In should have been saved.  ID was nil."
    p_sets = inv_in.piece_sets.all
    assert p_sets.length==1, "Inventory In should have only been associated with one piece set, was #{p_sets.length}."
    p = p_sets[0]
    assert p.order_line==ord_line, "Inventory piece set should be assoicated with original order line."
    assert p.shipment==s, "Inventory piece set should be associated with original shipment."
    assert s.piece_sets.length==1, "Shipment should only be associated with one piece set."
    assert ord_line.piece_sets.length==1, "Order line should only be associated with one piece set."
  end

  test "short receive" do
    quantity = 50
    short_remainder = 10
    vendor = companies(:vendor)
    product = vendor.vendor_products.first
    o = Order.create!(:vendor_id=>vendor.id)
    ord_line = o.order_lines.create!(:product_id => product.id,:line_number => 1,:ordered_qty => quantity)

    s = Shipment.create!(:vendor_id=>vendor.id)
    base_ps = s.piece_sets.build(:order_line_id => ord_line.id, :quantity => quantity, :product_id => product.id)
    base_ps.save!
    inv_in = s.receive({ord_line=>quantity-short_remainder})

    assert !inv_in.id.nil?, "Inventory In should have been saved. ID was nil."
    inventoried = inv_in.piece_sets.all
    assert inventoried.length == 1, "Inventory In should have been associated with 1 piece set, was #{inventoried.length}."
    ip = inventoried[0]
    assert s.piece_sets.length == 2, "Shipment should have two piece sets.  One with inventory in and the other without.  Had: #{s.piece_sets.length}."
    assert ip.shipment == s, "Inventoried piece set should be associated with shipment."
    assert ip.order_line == ord_line, "Inventoried piece set should be associated with order line."
    assert ip.quantity == (quantity-short_remainder), "Inventoried piece set had quantity of #{ip.quantity}, should have been: #{quantity-short_remainder}."
    no_ip = s.piece_sets.where(:inventory_in_id=>nil, :order_line_id=>ord_line.id).first
    assert no_ip.quantity == short_remainder, "Remainder had quantity of #{no_ip.quantity}, should have been: #{short_remainder}"
  end

  test "over receive" do
    quantity = 50
    overage = 10
    vendor = companies(:vendor)
    product = vendor.vendor_products.first
    o = Order.create!(:vendor_id=>vendor.id)
    ord_line = o.order_lines.create!(:product_id => product.id,:line_number => 1,:ordered_qty => quantity)

    s = Shipment.create!(:vendor_id=>vendor.id)
    base_ps = s.piece_sets.build(:order_line_id => ord_line.id, :quantity => quantity, :product_id => product.id)
    base_ps.save!
    inv_in = s.receive({ord_line=>quantity+overage})

    assert !inv_in.id.nil?, "Inventory In should have been saved. ID was nil."
    inventoried = inv_in.piece_sets.all
    assert inventoried.length == 2, "Inventory In should have been associated with 2 piece sets, was #{inventoried.length}."
    assert s.piece_sets.where(:order_line_id => ord_line.id, :quantity => quantity, 
      :product_id=>product.id, :inventory_in_id=>inv_in.id).length == 1,
      "Should have one piece set with original quantity match that is received"
     ovg = s.piece_sets.where(:order_line_id => ord_line.id, :quantity => overage,
      :product_id=>product.id, :inventory_in_id=>inv_in.id)
     assert ovg.length == 1, "Should have one piece set with overage quanitty that is received"
     assert ovg.first.adjustment_type == "Excess Receipt", "Should be marked as \"Excess Receipt\", was #{ovg.first.adjustment_type}."
  end

  test "unmatched receive" do 
    quantity = 50
    vendor = companies(:vendor)
    product = vendor.vendor_products.first
    o = Order.create!(:vendor_id=>vendor.id)
    ord_line = o.order_lines.create!(:product_id => product.id,:line_number => 1,:ordered_qty => 10)

    s = Shipment.create!(:vendor_id=>vendor.id)
    base_ps = s.piece_sets.build(:order_line_id => ord_line.id, :quantity => 10, :product_id => product.id)
    inv = InventoryIn.create!
    base_ps.inventory_in = inv
    base_ps.save!
    inv_in = s.receive({ord_line=>quantity})
    
    assert inv_in.piece_sets.length == 1, "Should find one piece set."
    assert inv_in.id != inv.id, "Should not be the same inventory receipt as the first time"
    ps = inv_in.piece_sets.first
    assert ps!=base_ps, "Should not be base piece set."
    assert ps.order_line == ord_line, "Should match order line."
    assert ps.shipment == s, "Should match shipment"
    assert ps.quantity == quantity, "Should match quantity, was #{ps.quantity}"
    assert ps.adjustment_type == "Unmatched Receipt", "Should have adjustment type \"Unmatched Receipt\", had: #{ps.adjustment_type}."
  end
  
end
