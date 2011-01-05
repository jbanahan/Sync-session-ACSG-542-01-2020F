require 'test_helper'

class SalesOrderTest < ActiveSupport::TestCase
  test "can edit & view" do
    mast_u = Company.where(:master=>true).first.users.first
    cust = Company.where(:customer=>true).first
    cust_u = cust.users.first
    wrong_cust_u = Company.where(:customer=>true).where("id <> ?",cust.id).first.users.first
    vend_u = Company.where({:vendor=>true, :customer=>false}).first.users.first
    
    so = SalesOrder.new(:customer_id=>cust.id)
    assert so.can_edit?(mast_u), "Master should be able to edit any sales order."
    assert !so.can_edit?(cust_u), "Customer should not be able to edit a sales order."
    assert !so.can_edit?(vend_u), "Vendor should not be able to edit a sales order."
    
    assert so.can_view?(mast_u), "Master should be able to view any sales order."
    assert so.can_view?(cust_u), "Customer should be able to view own sales order."
    assert !so.can_view?(wrong_cust_u), "Customer should not be able to view another customer's sales order."
    assert !so.can_view?(vend_u), "Vendor should not be able to view a sales order."
  end
  
  test "locked" do
    cust = Company.where(:customer=>true).first
    so = SalesOrder.new(:customer => cust)
    
    assert !so.locked?, "Sales order should not be locked because customer is not locked."
    cust.locked = true
    assert so.locked?, "Sales order should be locked because customer is locked."
  end
  
  test "make unpacked piece sets" do
    so = SalesOrder.find(1)
    ps = so.make_unpacked_piece_sets
    assert ps.length == 2, "Should have two lines returned."
    found1 = false
    found2 = false
    ps.each do |p|
      if p.sales_order_line_id == 2
        assert p.quantity == 4, "Line 1 should have quantity of 4, was #{p.quantity}"
        found1 = true
      elsif p.sales_order_line_id == 1
        assert p.quantity == 5, "Line 2 should have quantity of 5, was #{p.quantity}"
        found2 = true
      end
    end
    assert found1 && found2, "Didn't find both lines."
  end
end
