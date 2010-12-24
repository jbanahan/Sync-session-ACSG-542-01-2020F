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
    assert found.length==1 && found[0].id == 1, "Vendor didn't find product 1."
    u = User.find(4)
    found = Product.find_can_view(u)
    assert found.length==0
  end
  
  test "shallow merge into" do
    base_attribs = {
      :unique_identifier => "ui",
      :part_number => "bpart",
      :name => "bname",
      :description => "bdesc",
      :vendor_id => 2,
      :division_id => 1
    }
    base = Product.new(base_attribs)
    newer_attribs = {
      :unique_identifier => "to be ignored",
      :part_number => "npart",
      :name => "nname",
      :description => "ndesc",
      :vendor_id => 3,
      :division_id => 2
    }
    newer = Product.new(newer_attribs)
    base.save!
    newer.save!
    newer.updated_at = DateTime.new(2012,3,9)
    newer.created_at = DateTime.new(2007,5,2)
    target_attribs = {'unique_identifier' => base.unique_identifier,
      'part_number' => newer.part_number,
      'name' => newer.name,
      'description' => newer.description,
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
  
  test "state hash" do
    #base quantities for results 
    in_transit = 6
    not_departed = 5
    not_shipped = 4
    arrived = 3
    inventory = 9
    inventory_out = 4
    total_pieces = not_departed+in_transit+not_shipped+arrived+inventory#+inventory_out
    #setup
    ship_in_transit = Shipment.new(:vendor_id => 2, :reference => 'in transit', :atd => 7.days.ago )
    ship_in_transit.save!
    ship_not_departed = Shipment.new(:vendor_id => 2, :reference => 'not departed')
    ship_not_departed.save!
    ship_arrived = Shipment.new(:vendor_id=>2,:reference=>'arrived',:atd => 10.days.ago,:ata=> 2.days.ago)
    ship_arrived.save!
    inventory_in = InventoryIn.create()
    p = Product.new(:unique_identifier => 'statehash',:vendor_id => 2,:division_id => 1)
    p.save!
    ord = Order.new(:order_number => 'ordnum-sh',:vendor_id => 2,:division_id => 1)
    ord.save!
    o_line = ord.order_lines.create(:ordered_qty => total_pieces,:product_id=>p.id,:line_number=>1)
    o_line.piece_sets.create(
      :order_line_id => o_line.id,
      :product_id => p.id,
      :shipment_id => ship_not_departed.id,
      :quantity => not_departed
    )
    o_line.piece_sets.create(
      :order_line_id => o_line.id,
      :product_id => p.id,
      :shipment_id => ship_in_transit.id,
      :quantity => in_transit
    )
    o_line.piece_sets.create(
      :order_line_id => o_line.id,
      :product_id => p.id,
      :shipment_id => ship_arrived.id,
      :quantity => arrived
    )
    o_line.piece_sets.create(
      :order_line_id => o_line.id,
      :product_id => p.id,
      :inventory_in_id => inventory_in.id,
      :quantity => inventory
    )
    io = InventoryOut.create!()
    PieceSet.create!(:product_id => p.id, :inventory_out => io, :quantity => inventory_out)
    results = p.state_hash(User.find(1))    
    assert results[:arrived]==arrived, "Arrived should have been #{arrived}, was #{results[:arrived]}"
    assert results[:in_transit]==in_transit, "In Tranist should have been #{in_transit}, was #{results[:in_transit]}"
    assert results[:not_departed]==not_departed, "Not Departed should have been #{not_departed}, was #{results[:not_departed]}"
    assert results[:not_shipped]==not_shipped, "Not Shipped should have been #{not_shipped}, was #{results[:not_shipped]}"
    assert results[:inventory]==inventory-inventory_out, "Inventory should have been #{inventory-inventory_out}, was #{results[:inventory]}"
    assert results.size == 5, "Results should have been hash of 5, was #{results.size}"
  end
end
