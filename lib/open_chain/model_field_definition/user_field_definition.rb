module OpenChain; module ModelFieldDefinition; module UserFieldDefinition
  def add_user_fields
    add_fields CoreModule::USER, [
      [1, :usr_username, :username, "Username", {data_type: :string}],
      [2, :usr_email, :email, "Email", {data_type: :string}],
      [3, :usr_first_name, :first_name, "First name", {data_type: :string}],
      [4, :usr_last_name, :last_name, "Last name", {data_type: :string}],
      [5, :usr_time_zone, :time_zone, "Time zone", {data_type: :string}],
      [6, :usr_email_format, :email_format, "Email format", {data_type: :string}],
      [7, :usr_homepage, :homepage, "VFI Track Homepage", {data_type: :string}],
      [8, :usr_department, :department, "Department", {data_type: :string}],
      [9, :usr_tariff_subscribed, :tariff_subscribed, "Tariff Subscribed", {data_type: :boolean}],
      [10, :usr_disabled, :disabled, "Account Disabled", {data_type: :boolean}],
      [11, :usr_admin, :admin, "Administrator", {data_type: :boolean}],
      [12, :usr_disallow_password, :disallow_password, "Disallow Password", {data_type: :boolean}],
      [13, :usr_portal_mode, :portal_mode, "Portal Mode", {data_type: :string}],
      [14, :usr_support_agent, :support_agent, "Support Agent", {data_type: :string}],
      [15, :usr_system_user, :system_user, "System User", {data_type: :boolean}],
      [16, :usr_sys_admin, :sys_admin, "System Administrator", {data_type: :boolean}],
      [17, :usr_password_reset, :password_reset, "Reset Password", {data_type: :boolean}],
      [18, :usr_commercial_invoice_edit, :commercial_invoice_edit, "Customer Invoice Edit", {data_type: :boolean}],
      [19, :usr_commercial_invoice_view, :commercial_invoice_view, "Customer Invoice View", {data_type: :boolean}],
      [20, :usr_broker_invoice_edit, :broker_invoice_edit, "Broker Invoice Edit", {data_type: :boolean}],
      [21, :usr_broker_invoice_view, :broker_invoice_view, "Broker Invoice View", {data_type: :boolean}],
      [22, :usr_delivery_attach, :delivery_attach, "Delivery Attach", {data_type: :boolean}],
      [23, :usr_delivery_comment, :delivery_comment, "Delivery Comment", {data_type: :boolean}],
      [24, :usr_delivery_delete, :delivery_delete, "Delivery Delete", {data_type: :boolean}],
      [25, :usr_delivery_edit, :delivery_edit, "Delivery Edit", {data_type: :boolean}],
      [26, :usr_delivery_view, :delivery_view, "Delivery View", {data_type: :boolean}],
      [27, :usr_drawback_edit, :drawback_edit, "Drawback Edit", {data_type: :boolean}],
      [28, :usr_drawback_view, :drawback_view, "Drawback View", {data_type: :boolean}],
      [29, :usr_entry_attach, :entry_attach, "Entry Attach", {data_type: :boolean}],
      [30, :usr_entry_comment, :entry_comment, "Entry Comment", {data_type: :boolean}],
      [31, :usr_entry_edit, :entry_edit, "Entry Edit", {data_type: :boolean}],
      [32, :usr_entry_view, :entry_view, "Entry View", {data_type: :boolean}],
      [33, :usr_order_attach, :order_attach, "Order Attach", {data_type: :boolean}],
      [34, :usr_order_comment, :order_comment, "Order Comment", {data_type: :boolean}],
      [35, :usr_order_delete, :order_delete, "Order Delete", {data_type: :boolean}],
      [36, :usr_order_edit, :order_edit, "Order Edit", {data_type: :boolean}],
      [37, :usr_order_view, :order_view, "Order View", {data_type: :boolean}],
      [38, :usr_product_attach, :product_attach, "Product Attach", {data_type: :boolean}],
      [39, :usr_product_comment, :product_comment, "Product Comment", {data_type: :boolean}],
      [40, :usr_product_edit, :product_edit, "Product Edit", {data_type: :boolean}],
      [41, :usr_product_view, :product_view, "Product View", {data_type: :boolean}],
      [42, :usr_project_edit, :project_edit, "Project Edit", {data_type: :boolean}],
      [43, :usr_project_view, :project_view, "Project View", {data_type: :boolean}],
      [44, :usr_sales_order_attach, :sales_order_attach, "Sales Order Attach", {data_type: :boolean}],
      [45, :usr_sales_order_comment, :sales_order_comment, "Sales Order Comment", {data_type: :boolean}],
      [46, :usr_sales_order_delete, :sales_order_delete, "Sales Order Delete", {data_type: :boolean}],
      [47, :usr_sales_order_edit, :sales_order_edit, "Sales Order Edit", {data_type: :boolean}],
      [48, :usr_sales_order_view, :sales_order_view, "Sales Order View", {data_type: :boolean}],
      [49, :usr_security_filing_attach, :security_filing_attach, "Security Filing Attach", {data_type: :boolean}],
      [50, :usr_security_filing_comment, :security_filing_comment, "Security Filing Comment", {data_type: :boolean}],
      [51, :usr_security_filing_edit, :security_filing_edit, "Security Filing Edit", {data_type: :boolean}],
      [52, :usr_security_filing_view, :security_filing_view, "Security Filing View", {data_type: :boolean}],
      [53, :usr_shipment_attach, :shipment_attach, "Shipment Attach", {data_type: :boolean}],
      [54, :usr_shipment_comment, :shipment_comment, "Shipment Comment", {data_type: :boolean}],
      [55, :usr_shipment_delete, :shipment_delete, "Shipment Delete", {data_type: :boolean}],
      [56, :usr_shipment_edit, :shipment_edit, "Shipment Edit", {data_type: :boolean}],
      [57, :usr_shipment_view, :shipment_view, "Shipment View", {data_type: :boolean}],
      [58, :usr_survey_edit, :survey_edit, "Survey Edit", {data_type: :boolean}],
      [59, :usr_survey_view, :survey_view, "Survey View", {data_type: :boolean}],
      [60, :usr_trade_lane_attach, :trade_lane_attach, "Trade Lane Attach", {data_type: :boolean}],
      [61, :usr_trade_lane_comment, :trade_lane_comment, "Trade Lane Comment", {data_type: :boolean}],
      [62, :usr_trade_lane_edit, :trade_lane_edit, "Trade Lane Edit", {data_type: :boolean}],
      [63, :usr_trade_lane_view, :trade_lane_view, "Trade Lane View", {data_type: :boolean}],
      [64, :usr_variant_edit, :variant_edit, "Variant Edit", {data_type: :boolean}],
      [65, :usr_vendor_attach, :vendor_attach, "Vendor Attach", {data_type: :boolean}],
      [66, :usr_vendor_comment, :vendor_comment, "Vendor Comment", {data_type: :boolean}],
      [67, :usr_vendor_edit, :vendor_edit, "Vendor Edit", {data_type: :boolean}],
      [68, :usr_vendor_view, :vendor_view, "Vendor View", {data_type: :boolean}],
      [69, :usr_vfi_invoice_edit, :vfi_invoice_edit, "VFI Invoice Edit", {data_type: :boolean}],
      [70, :usr_vfi_invoice_view, :vfi_invoice_view, "VFI Invoice View", {data_type: :boolean}],
      [71, :usr_password_changed_at, :password_changed_at, "Password Changed At", {data_type: :datetime}],
      [72, :usr_password_expired, :password_expired, "Password Expired", {data_type: :boolean}],
      [73, :usr_password_locked, :password_locked, "Password Locked", {data_type: :boolean}],
      [74, :usr_password_reset, :password_reset, "Password Reset", {data_type: :boolean}],
      [75, :usr_default_report_date_format, :default_report_date_format, "Default Report Date Format", {data_type: :string}]
    ]
    add_fields CoreModule::USER, make_company_arrays(100, 'usr', 'users', 'comp', 'Company', 'company')
  end
end; end; end
