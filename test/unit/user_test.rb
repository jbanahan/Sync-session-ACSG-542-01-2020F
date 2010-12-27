require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "can_view?" do
    u = User.find(1)
    assert User.find(1).can_view?(u), "Master user can't view self."
    assert User.find(2).can_view?(u), "Master user can't view other."
    u = User.find(2)
    assert User.find(2).can_view?(u), "Non-master can't view self."
    assert !User.find(1).can_view?(u), "Non-master can view other."
  end

  test "can_edit?" do
    u = User.find(1)
    assert User.find(1).can_edit?(u), "Master user can't edit self."
    assert User.find(2).can_edit?(u), "Master user can't edit other."
    u = User.find(2)
    assert User.find(2).can_edit?(u), "Non-master can't edit self."
    assert !User.find(1).can_edit?(u), "Non-master can edit other."
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
    u = User.find(1)
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_sales_orders?, "Master user should be able to view sales orders."
    assert u.edit_sales_orders?, "Master user should be able to edit sales orders."
    assert u.add_sales_orders?, "Master user should be able to create sales orders."
    u = User.find(6)
    assert u.company.customer?, "Setup wrong, user six should be part of a customer company."
    assert u.view_sales_orders?, "Customer user should be able to view sales orders."
    assert !(u.edit_sales_orders? || u.add_sales_orders?), "Customer should NOT be able to edit or create sales orders."
    u = User.find(2)
    assert !(u.company.master? || u.company.customer?), "Setup wrong, user two should not be part of a master or customer company."
    assert !(u.view_sales_orders? ||
             u.edit_sales_orders? ||
             u.add_sales_orders?), "Non-customer & non-master should NOT be able to create/edit/view sales orders."
  end
  
  test "shipment permissions" do
    u = User.find(1)
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_shipments?, "Master user should be able to view shipments."
    assert u.edit_shipments?, "Master user should be able to edit shipments."
    assert u.add_shipments?, "Master user should be able to create shipments."
    u = User.find(2)
    assert u.company.vendor?, "Setup wrong, user 2 should be part of a vendor company."
    assert u.view_shipments?, "Vendor user should be able to view shipments."
    assert u.edit_shipments?, "Vendor user should be able to edit shipments."
    assert u.add_shipments?, "Vendor user should be able to add shipments."
    u = User.find(4)
    assert u.company.carrier?, "Setup wrong, user 4 should be part of a vendor company."
    assert u.view_shipments?, "Carrier user should be able to view shipments."
    assert u.edit_shipments?, "Carrier user should be able to edit shipments."
    assert u.add_shipments?, "Carrier user should be able to add shipments."
    u = User.find(6)
    assert !(u.company.master? || u.company.vendor? || u.company.carrier?), "Setup wrong, user 6 should not be part of a master or customer company."
    assert !(u.view_shipments? ||
             u.edit_shipments? ||
             u.add_shipments?), "Non-vendor, non-carrier & non-master should NOT be able to create/edit/view shipments."
  end
end
