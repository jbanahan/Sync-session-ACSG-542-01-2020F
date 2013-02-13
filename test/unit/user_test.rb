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


  test "classification permissions" do
    u = users(:masteruser)
    enable_all_personal_permissions u
    assert u.edit_classifications?
    u.classification_edit = false
    assert !u.edit_classifications?

    [users(:vendoruser),users(:carrier4user),users(:customer6user)].each do |usr|
      enable_all_personal_permissions usr
      assert !usr.edit_classifications?
    end
  end

  test "product permissions" do 
    u = users(:masteruser)
    enable_all_personal_permissions u
    assert u.view_products?
    assert u.edit_products?
    assert u.add_products?
    assert u.delete_products?
    assert u.comment_products?
    assert u.attach_products?
    u.product_attach = false
    assert !u.attach_products?
    u.product_comment = false
    assert !u.comment_products?
    u.product_edit = false
    assert !u.add_products?
    assert !u.edit_products?
    u.product_view = false
    assert !u.view_products?

    u = users(:vendoruser)
    enable_all_personal_permissions u
    assert u.view_products?
    assert !u.edit_products? && !u.add_products?
    assert u.comment_products?
    assert u.attach_products?

    u = users(:carrier4user)
    enable_all_personal_permissions u
    assert u.view_products?
    assert !u.edit_products? && !u.add_products?
    assert u.comment_products?
    assert u.attach_products?

    u = users(:customer6user)
    enable_all_personal_permissions u
    #Every company can view/comment/attach products - the controlling permissions for those are set at user level only now
    assert u.view_products? && !u.edit_products? && !u.add_products? && u.comment_products? && u.attach_products?
  end
  test "order permissions" do
    u = users(:masteruser)
    assert u.view_orders?
    assert u.edit_orders?
    assert u.add_orders?
    assert u.delete_orders?
    assert u.comment_orders?
    assert u.attach_orders?
    u.order_attach = false
    assert !u.attach_orders?
    u.order_comment = false
    assert !u.comment_orders?
    u.order_delete = false
    assert !u.delete_orders?
    u.order_edit = false
    assert !u.edit_orders?
    u.order_view = false
    assert !u.view_orders?

    u = users(:vendoruser)
    enable_all_personal_permissions u
    assert u.order_edit? #test personal permission
    assert u.view_orders?
    assert !u.edit_orders?
    assert !u.delete_orders?
    assert !u.add_orders?
    assert u.attach_orders?
    assert u.comment_orders?

    u = users(:carrier4user)
    enable_all_personal_permissions u
    assert !u.view_orders? && !u.edit_orders? && !u.delete_orders? && !u.add_orders? && !u.attach_orders? && !u.comment_orders?

    u = users(:customer6user)
    enable_all_personal_permissions u
    assert !u.view_orders? && !u.edit_orders? && !u.delete_orders? && !u.add_orders? && !u.attach_orders? && !u.comment_orders?
  end

  test "sales order permissions" do
    u = users(:masteruser)
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_sales_orders?, "Master user should be able to view sales orders."
    assert u.edit_sales_orders?, "Master user should be able to edit sales orders."
    assert u.add_sales_orders?, "Master user should be able to create sales orders."
    assert u.comment_sales_orders?
    assert u.attach_sales_orders?
    u.sales_order_attach = false
    assert !u.attach_sales_orders?
    u.sales_order_comment = false
    assert !u.comment_sales_orders?
    u.sales_order_edit = false
    assert !u.edit_sales_orders? && !u.add_sales_orders?
    u.sales_order_delete = false
    assert !u.delete_sales_orders?
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
    u.shipment_view = true
    u.shipment_edit = true
    u.shipment_attach = true
    u.shipment_comment = true
    u.shipment_delete = true
    assert u.company.master?, "Setup wrong, user one should be part of master company."
    assert u.view_shipments?, "Master user should be able to view shipments."
    assert u.edit_shipments?, "Master user should be able to edit shipments."
    assert u.add_shipments?, "Master user should be able to create shipments."
    assert u.comment_shipments?
    assert u.attach_shipments?
    assert u.delete_shipments?
    u.shipment_view = false
    assert !u.view_shipments?
    u.shipment_edit = false
    assert !u.edit_shipments?
    u.shipment_attach = false
    assert !u.attach_shipments?
    u.shipment_comment = false
    assert !u.comment_shipments?
    u.shipment_delete = false
    assert !u.delete_shipments?
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
    assert u.delete_deliveries?
    assert u.attach_deliveries?
    assert u.comment_deliveries?
    u.delivery_view = false
    assert !u.view_deliveries?
    u.delivery_edit = false
    assert !u.edit_deliveries?
    assert !u.add_deliveries?
    u.delivery_delete = false
    assert !u.delete_deliveries?
    u.delivery_comment = false
    assert !u.comment_deliveries?
    u.delivery_attach = false
    assert !u.attach_deliveries?
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
    a_u = users(:adminuser)
    assert !a_u.view_shipments? && !a_u.edit_shipments? && !a_u.add_shipments?, "Shouldn't be able to work with shipments if they're not enabled."
    m.sales_order_enabled = false
    m.save!
    assert !a_u.view_sales_orders? && !a_u.edit_sales_orders? && !a_u.add_sales_orders?, "Shouldn't be able to work with sales orders if they're not enabled."
    m.delivery_enabled = false
    m.save!
    assert !a_u.view_deliveries? && !a_u.edit_deliveries? && !a_u.add_deliveries?, "Shouldn't be able to work with deliveries if they're not enabled."
    m.classification_enabled = false
    m.save!
    assert !a_u.edit_classifications? && !a_u.add_classifications?, "Shouldn't be able to work with classifications if they're not enabled."
  end
  
  test "debug_active?" do 
    u = User.first
    u.debug_expires = Time.now - 1.hour
    assert !u.debug_active?, "Debug shouldn't be active if it expired an hour ago."
    u.debug_expires = nil
    assert !u.debug_active?, "Debug shouldn't be active if it is nil"
    u.debug_expires = Time.now + 1.hour
    assert u.debug_active?, "Debug should be active it if expires an hour from now."
  end
end
