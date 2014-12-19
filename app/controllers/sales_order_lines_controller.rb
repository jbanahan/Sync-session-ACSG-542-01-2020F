class SalesOrderLinesController < LinesController
  def find_parent
    SalesOrder.find(params[:sales_order_id])
  end
  def find_line
    SalesOrderLine.find(params[:id])
  end
  def render_parent_path
    'sales_orders/show'
  end
  def child_objects p
    p.sales_order_lines
  end
  def set_products_variable p
    # This is obviously not going to work
    # for real usage, but we're not really using it
    # in real cases yet anyway, so I'm limiting to 1000
    # so we don't turn on and accidently load 300K products
    # into a select box
    @products = Product.limit(1000).all
  end
  def set_parent_variable obj
    @sales_order = obj
  end
  def module_name
    "sale"
  end
  def edit_line_path parent, line
    edit_sales_order_sales_order_line_path parent, line
  end
  def update_symbol
    :sales_order_line
  end
  def update_custom_field_symbol
    :salesorderline_cf
  end
end
