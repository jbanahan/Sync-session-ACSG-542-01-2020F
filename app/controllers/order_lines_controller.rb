class OrderLinesController < LinesController

  def find_parent
    Order.find(params[:order_id])
  end

  def find_line
    OrderLine.find(params[:id])
  end

  def render_parent_path
    'orders/show'
  end

  def child_objects parent_obj
    parent_obj.order_lines
  end

  def set_products_variable parent_obj
    @products = Product.where(:vendor_id=>parent_obj.vendor)
  end

  def set_parent_variable obj
    @order = obj
  end

  def module_name
    "order"
  end

  def edit_line_path parent, line
    edit_order_order_line_path parent, line 
  end

  def update_symbol
    :order_line
  end
  def update_custom_field_symbol
    :orderline_cf
  end
  
end
