require 'test_helper'

class PieceSetTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "quantity greater than zero" do
    p = PieceSet.find(1)
    p.quantity = -1
    p.save
    err = p.errors[:quantity] 
    assert err.size==1, "Did not find quantity error."
  end
  
  test "unique keys allows save with same id" do
    p = PieceSet.new(:order_line_id => 999, :product_id => 1, :quantity => 100)
    p.save!
    p.quantity = 3
    assert p.save, "Did not allow resave after quantity change."
  end
  
  test "keys must be unique" do
    p = PieceSet.new(:order_line_id => 999, :product_id => 1, :quantity => 100)
    p.save!
    new = PieceSet.create(:order_line_id => 999, :product_id => 1, :quantity => 100)
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: 999, Shipment: , Inventory In: , SalesOrderLine: , Delivery: , Inventory Out: , Adjustment: )"),
      "Did not find error for piece set with only order line & product."
    p = PieceSet.new(:product_id => 1, :quantity => 100)
    p.save!
    new = PieceSet.create(:product_id => 1, :quantity => 100)
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: , Shipment: , Inventory In: , SalesOrderLine: , Delivery: , Inventory Out: , Adjustment: )"),
      "Did not find error for piece set with only product."
    p = PieceSet.new(:product_id => 1, :shipment_id => 999, :quantity => 100)
    p.save!
    new = PieceSet.create(:product_id => 1, :shipment_id => 999, :quantity => 100)
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: , Shipment: 999, Inventory In: , SalesOrderLine: , Delivery: , Inventory Out: , Adjustment: )"),
      "Did not find error for piece set with only product & shipment"
    p = PieceSet.new(:product_id => 1, :shipment_id => 999, :order_line_id => 999, :quantity => 100)
    p.save!
    new = PieceSet.create(:product_id => 1, :shipment_id => 999, :order_line_id => 999, :quantity => 100)
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: 999, Shipment: 999, Inventory In: , SalesOrderLine: , Delivery: , Inventory Out: , Adjustment: )"),
      "Did not find error for piece set with product, order line, & shipment"
    p = PieceSet.new(:product_id => 1, :shipment_id => 999, :inventory_in_id => 999, :quantity => 100)
    p.save!
    new = PieceSet.create(:product_id => 1, :shipment_id => 999, :inventory_in_id => 999, :quantity => 100)
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: , Shipment: 999, Inventory In: 999, SalesOrderLine: , Delivery: , Inventory Out: , Adjustment: )"),
      "Did not find error for piece set with shipment, inventory in"
    p = PieceSet.new(:product_id => 1, :shipment_id => 999, :inventory_in_id => 999, :quantity => 100, :adjustment_type => 'adj')
    p.save!
    new = PieceSet.create(:product_id => 1, :shipment_id => 999, :inventory_in_id => 999, :quantity => 100, :adjustment_type => 'adj')
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: , Shipment: 999, Inventory In: 999, SalesOrderLine: , Delivery: , Inventory Out: , Adjustment: adj)"),
      "Did not find error for piece set with shipment, inventory in, adjustment type"
    p = PieceSet.new(:product_id => 1, :delivery_id => 999, :sales_order_line_id => 999, :inventory_out_id => 999, :quantity => 1)
    p.save!
    new = PieceSet.create(:product_id => 1, :delivery_id => 999, :sales_order_line_id => 999, :inventory_out_id => 999, :quantity => 1)
    assert new.errors[:base].include?("PieceSet with these keys already exists. (Product: 1, OrderLine: , Shipment: , Inventory In: , SalesOrderLine: 999, Delivery: 999, Inventory Out: 999, Adjustment: )"),
      "Did not find error for piece set with delivery, inventory out, and sales order line"
  end
  
  test "locked?" do
    c_locked = Company.create!(:name => "Locked Company", :vendor => true, :carrier => true, :locked => true)
    prod = Product.create!(:name => "Locked Prod", :vendor => c_locked, :division => Division.first, :unique_identifier => "ps-Lock-test")
    ps = PieceSet.create!(:product => prod, :quantity => 5)
    assert ps.locked?, "Did not find lock with locked vendor on product (no other FKs)"
    prod.vendor = Company.find(2) #not locked
    prod.save!
    assert !ps.locked?, "Should not have been locked with company 2 as vendor."
    shp = Shipment.create!(:carrier => c_locked, :vendor => Company.find(2))
    ps.shipment = shp
    assert shp.locked?, "Shipment should be locked." #double checking setup
    assert ps.locked?, "Should have been locked when associated to locked shipment."
  end
end
