class DeliveryLinesController < LinesController
#LinesController callback(s)
  def before_save line
    sale_line_id = line.linked_sales_order_line_id
    ok = true
    unless sale_line_id.blank?
      soline = SalesOrderLine.find(sale_line_id)
      if !soline.nil? && !soline.sales_order.can_view?(current_user)
        ok = false
        add_flash :errors, "You do not have permission to assign values from Sale \"#{soline.sales_order.order_number}\""
      end
    end
    ok
  end

#BELOW HERE ARE HELPERS FOR LinesController
  def find_parent
    Delivery.find(params[:delivery_id])
  end
  def find_line
    DeliveryLine.find(params[:id])
  end
  def render_parent_path
    'deliveries/show'
  end
  def child_objects p
    p.delivery_lines
  end
  def set_products_variable p
    @products = Product.all
  end
  def set_parent_variable obj
    @delivery = obj
  end
  def module_name
    "delivery"
  end
  def edit_line_path parent, line
    edit_delivery_delivery_line_path parent, line
  end
  def update_symbol
    :delivery_line
  end
  def update_custom_field_symbol
    :deliveryline_cf
  end
end
