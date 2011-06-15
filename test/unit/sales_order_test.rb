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
  
  test "find same" do
    s = SalesOrder.create!(:order_number=>"123bbb",:customer_id=>companies(:customer).id)
    s2 = SalesOrder.new(:order_number=>s.order_number)
    assert_equal s, s2.find_same
    s3 = SalesOrder.new(:order_number=>123)
    assert_nil s3.find_same
  end
end
