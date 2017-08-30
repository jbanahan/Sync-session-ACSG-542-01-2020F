module ConfigMigrations; module LL; class LlSow1274
  def up
    configure_vendor_permissions
  end

  def configure_vendor_permissions
    User.joins(:company).where('companies.vendor = 1').update_all(
      shipment_view:true,
      shipment_edit:true,
      shipment_comment:true,
      shipment_attach:true,
      order_view:true,
      order_edit:true,
      order_comment:true,
      order_attach:true,
      product_view:true
    )
  end
end; end; end