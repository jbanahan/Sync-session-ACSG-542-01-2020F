require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "can_view?" do
    u = users(:masteruser)
    assert u.can_view?(u), "Master user can't view self."
    assert !users(:vendoruser).can_view?(u), "Master user can view other."
    u = users(:vendoruser)
    assert u.can_view?(u), "Non-master can't view self."
    assert !users(:masteruser).can_view?(u), "Non-master can view other."
    u = users(:adminuser)
    assert u.can_view?(u), "Admin user can't view self."
    assert users(:vendoruser).can_view?(u), "Admin user can't view other."
  end

  test "can_edit?" do
    u = users(:adminuser)
    assert u.can_edit?(u), "Admin user can't edit self."
    assert users(:vendoruser).can_edit?(u), "Admin user can't edit other."
    u = users(:masteruser)
    assert users(:masteruser).can_edit?(u), "Master user can't edit self."
    assert !users(:vendoruser).can_edit?(u), "Master user can edit other."
    u = users(:vendoruser)
    assert users(:vendoruser).can_edit?(u), "Non-master can't edit self."
    assert !users(:masteruser).can_edit?(u), "Non-master can edit other."
  end

  test "full_name" do
    u = User.new(:first_name => "First", :last_name => "Last", :username=>"uname")
    assert u.full_name == "First Last", "full_name should have been \"First Last\" was \"#{u.full_name}\""
    u.first_name = nil
    u.last_name = nil
    assert u.full_name == "uname", "full_name should have substituted username when first & last were nil"
    u.first_name = ''
    assert u.full_name == "uname", "full_name should have substituted username when length of first+last was 0"
  end

  test "sales order permissions" do
    u = users(:masteruser)
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_sales_orders?, "Master user should be able to view sales orders."
    assert u.edit_sales_orders?, "Master user should be able to edit sales orders."
    assert u.add_sales_orders?, "Master user should be able to create sales orders."
    u = User.find(6)
    assert u.company.customer?, "Setup wrong, user six should be part of a customer company."
    assert u.view_sales_orders?, "Customer user should be able to view sales orders."
    assert !(u.edit_sales_orders? || u.add_sales_orders?), "Customer should NOT be able to edit or create sales orders."
    u = users(:vendoruser)
    assert !(u.company.master? || u.company.customer?), "Setup wrong, user two should not be part of a master or customer company."
    assert !(u.view_sales_orders? ||
             u.edit_sales_orders? ||
             u.add_sales_orders?), "Non-customer & non-master should NOT be able to create/edit/view sales orders."
  end
  
  test "shipment permissions" do
    u = users(:masteruser)
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_shipments?, "Master user should be able to view shipments."
    assert u.edit_shipments?, "Master user should be able to edit shipments."
    assert u.add_shipments?, "Master user should be able to create shipments."
    u = users(:vendoruser)
    assert u.company.vendor?, "Setup wrong, user 2 should be part of a vendor company."
    assert u.view_shipments?, "Vendor user should be able to view shipments."
    assert u.edit_shipments?, "Vendor user should be able to edit shipments."
    assert u.add_shipments?, "Vendor user should be able to add shipments."
    u = User.find(4)
    assert u.company.carrier?, "Setup wrong, user 4 should be part of a carrier company."
    assert u.view_shipments?, "Carrier user should be able to view shipments."
    assert u.edit_shipments?, "Carrier user should be able to edit shipments."
    assert u.add_shipments?, "Carrier user should be able to add shipments."
    u = User.find(6)
    assert !(u.company.master? || u.company.vendor? || u.company.carrier?), "Setup wrong, user 6 should not be part of a master or customer company."
    assert !(u.view_shipments? ||
             u.edit_shipments? ||
             u.add_shipments?), "Non-vendor, non-carrier & non-master should NOT be able to create/edit/view shipments."
  end
  
  test "delivery permissions" do
    u = users(:masteruser)
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_deliveries?, "Master user should be able to view deliveries."
    assert u.edit_deliveries?, "Master user should be able to edit deliveries."
    assert u.add_deliveries?, "Master user should be able to add deliveries."
    u = User.find(6)
    assert u.company.customer?, "Setup wrong, user six should be part of a customer company."
    assert u.view_deliveries?, "Customer user should be able to view deliveries."
    assert !(u.edit_deliveries? || u.add_deliveries?), "Customer should NOT be able to edit or create deliveries."
    u = User.find(4)
    assert u.company.carrier?, "Setup wrong, user 4 should be part of carrier company."
    assert u.view_deliveries?, "Carrier user should be able to view deliveries."
    assert u.edit_deliveries?, "Carrier user should be able to edit deliveries."
    assert u.add_deliveries?, "Carrier user should be able to add deliveries."
    u = users(:vendoruser)
    assert !(u.company.master? || u.company.customer? || u.company.carrier?), "Setup wrong, user two should not be part of a master, carrier, or customer company."
    assert !(u.view_deliveries? ||
             u.edit_deliveries? ||
             u.add_deliveries?), "Non-customer, non-carrier, & non-master should NOT be able to create/edit/view deliveries."
  end

  test "classification permissions" do
    u = users(:masteruser)
    assert u.view_classifications?, "Master user should be able to view classifications."
    assert u.edit_classifications?, "Master user should be able to edit classifications."
    assert u.add_classifications?,  "Master user should be able to add classifications."
    u = users(:customer6user)
    assert !(u.view_classifications? || u.edit_classifications? || u.add_classifications?), "Customer should not be able to view, edit, add classifications."
    u = users(:vendoruser)
    assert u.view_classifications?, "Vendor should be able to view classifications."
    assert !(u.edit_classifications? || u.add_classifications?), "Vendor should not be able to edit or add classifications."
    u = users(:carrier4user)
    assert u.view_classifications?, "Carrier should be able to view classifications."
    assert !(u.edit_classifications? || u.add_classifications?), "Carrier should not be able to edit or add classifications."
  end
  
  test "milestone_plan permissions" do
    assert users(:adminuser).edit_milestone_plans?, "Admin user should be able to edit milestone plans."
    assert !users(:masteruser).edit_milestone_plans?, "Master should not be able to edit milestone plans."
    assert !users(:vendoruser).edit_milestone_plans?, "Non-master should not be able to edit milestone plans."
  end

  test "everything locked when MasterSetup disabled" do 
    m = MasterSetup.first
    m.order_enabled = false
    m.save!
    a_u = users(:adminuser)
    assert !a_u.view_orders? && !a_u.edit_orders? && !a_u.add_orders?, "Shouldn't be able to work with orders if they're not enabled."
    m.shipment_enabled = false
    m.save!
    assert !a_u.view_shipments? && !a_u.edit_shipments? && !a_u.add_shipments?, "Shouldn't be able to work with shipments if they're not enabled."
    m.sales_order_enabled = false
    m.save!
    assert !a_u.view_sales_orders? && !a_u.edit_sales_orders? && !a_u.add_sales_orders?, "Shouldn't be able to work with sales orders if they're not enabled."
    m.delivery_enabled = false
    m.save!
    assert !a_u.view_deliveries? && !a_u.edit_deliveries? && !a_u.add_deliveries?, "Shouldn't be able to work with deliveries if they're not enabled."
    m.classification_enabled = false
    m.save!
    assert !a_u.view_classifications? && !a_u.edit_classifications? && !a_u.add_classifications?, "Shouldn't be able to work with classifications if they're not enabled."
  end
end
