class ShipmentLinesController < LinesController

  def create_multiple
    o = find_parent
    action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>module_name}) {
      params[:lines].each do |p|
        order_line_id = p[1].delete(:order_line_id) #clear it out so the build method works for the shipment_line
        puts "ORDER LINE ID = #{order_line_id}"
        line = child_objects(o).build(p[1])
        if line.save && !order_line_id.blank?
          ord_line = OrderLine.find(order_line_id)
          unless ord_line.nil?
            if ord_line.order.can_view?(current_user)
              ps = line.piece_sets.create(:order_line=>ord_line,:quantity=>p[1][:quantity])
              errors_to_flash ps
            else
              add_flash :errors, "You do not have permission to assign values from order \"#{ord_line.order.order_number}\""
            end
          end
        end
        errors_to_flash line
      end
      redirect_to o
    }
  end

#BELOW HERE ARE CALLBACKS
  def after_update sline
    if params[:order_line_id]
      oline = OrderLine.find(params[:order_line_id])
      if oline.can_edit? current_user
        ps = PieceSet.where(:order_line_id=>oline,:shipment_line_id=>sline).first
        if ps.nil?
          ps = PieceSet.create(:order_line_id=>oline,:shipment_line_id=>sline,:quantity=>sline.quantity)
        else
          ps.quantity = sline.quantity
          ps.save
        end
      end
    end
  end
#BELOW HERE ARE HELPSERS FOR LinesController
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

