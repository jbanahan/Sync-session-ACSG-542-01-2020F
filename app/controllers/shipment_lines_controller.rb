class ShipmentLinesController < LinesController

#callback
  def before_save line, line_params
    order_line_id = line_params[:linked_order_line_id]
    ok_to_save = true
    unless order_line_id.blank?
      ord_line = OrderLine.where(id: order_line_id).first
      if !ord_line.nil? && !ord_line.order.can_view?(current_user)
        ok_to_save = false
        add_flash :errors, "You do not have permission to assign values from order \"#{ord_line.order.order_number}\""
      else 
        line.linked_order_line_id = ord_line
      end
    end
    ok_to_save
  end

#BELOW HERE ARE HELPERS FOR LinesController
  def find_parent
    Shipment.find(params[:shipment_id])
  end

  def find_line
    ShipmentLine.find(params[:id])
  end

  def render_parent_path
    'shipments/show'
  end

  def child_objects parent_obj
    parent_obj.shipment_lines
  end

  def set_products_variable parent_obj
    @products = Product.where(:vendor_id=>parent_obj.vendor)
  end

  def set_parent_variable obj
    @shipment = obj
  end

  def module_name
    "shipment"
  end

  def edit_line_path parent, line
    edit_shipment_shipment_line_path parent, line 
  end

  def update_symbol
    :shipment_line
  end
  def update_custom_field_symbol
    :shipmentline_cf
  end
  
end

