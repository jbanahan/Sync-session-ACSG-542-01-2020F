module Api; module V1; class ShipmentsController < Api::V1::ApiController
  def index
    render_search CoreModule::SHIPMENT
  end

  def show
    render_show CoreModule::SHIPMENT
  end

  def create
    do_create CoreModule::SHIPMENT
  end

  def update
    do_update CoreModule::SHIPMENT
  end

  def save_object h
    shp = h['id'].blank? ? Shipment.new : Shipment.find(h['id'])
    original_importer = shp.importer
    import_fields h, shp, CoreModule::SHIPMENT
    load_containers shp, h
    load_lines shp, h
    raise StatusableError.new("You do not have permission to save this Shipment.",:forbidden) unless shp.can_edit?(current_user)
    shp.save if shp.errors.full_messages.blank?
    shp
  end
  def obj_to_json_hash s
    headers_to_render = limit_fields([
      :shp_ref,
      :shp_mode,
      :shp_ven_name,
      :shp_ven_syscode,
      :shp_ship_to_name,
      :shp_ship_from_name,
      :shp_car_name,
      :shp_car_syscode,
      :shp_imp_name,
      :shp_imp_syscode,
      :shp_master_bill_of_lading,
      :shp_house_bill_of_lading,
      :shp_booking_number,
      :shp_receipt_location,
      :shp_freight_terms,
      :shp_lcl,
      :shp_shipment_type,
      :shp_booking_shipment_type,
      :shp_booking_mode,
      :shp_vessel,
      :shp_voyage,
      :shp_vessel_carrier_scac,
      :shp_booking_received_date,
      :shp_booking_confirmed_date,
      :shp_booking_cutoff_date,
      :shp_booking_est_arrival_date,
      :shp_booking_est_departure_date,
      :shp_docs_received_date,
      :shp_cargo_on_hand_date,
      :shp_est_departure_date,
      :shp_departure_date,
      :shp_est_arrival_port_date,
      :shp_arrival_port_date,
      :shp_est_delivery_date,
      :shp_delivered_date
    ] + custom_field_keys(CoreModule::SHIPMENT))

    line_fields_to_render = limit_fields([
      :shpln_line_number,
      :shpln_shipped_qty,
      :shpln_puid,
      :shpln_pname,
      :shpln_container_uid,
      :shpln_container_number,
      :shpln_container_size
    ] + custom_field_keys(CoreModule::SHIPMENT_LINE))

    container_fields_to_render = ([
      :con_uid,
      :con_container_number,
      :con_container_size,
      :con_size_description,
      :con_weight,
      :con_seal_number,
      :con_teus,
      :con_fcl_lcl,
      :con_quantity,
      :con_uom
    ] + custom_field_keys(CoreModule::CONTAINER))
    
    h = {id: s.id}
    headers_to_render.each {|uid| h[uid] = export_field(uid,s)}
    s.shipment_lines.each do |sl|
      h['lines'] ||= []
      slh = {id: sl.id}
      line_fields_to_render.each {|uid| slh[uid] = export_field(uid,sl)}
      if params[:include] && params[:include].match(/order_lines/)
        slh['order_lines'] = render_order_fields(sl) 
      end
      h['lines'] << slh
    end
    s.containers.each do |c|
      h['containers'] ||= []
      ch = {id: c.id}
      container_fields_to_render.each {|uid| ch[uid] = export_field(uid,c)}
      h['containers'] << ch
    end
    h
  end
  private
  #return hash with extra order line fields
  def render_order_fields shipment_line
    ord_ord_num = ModelField.find_by_uid(:ord_ord_num)
    ord_cust_ord_no = ModelField.find_by_uid(:ord_cust_ord_no)
    shipment_line.piece_sets.collect do |ps|
      if ps.order_line_id
        ol = ps.order_line
        order = ol.order
        olh = {'allocated_quantity'=>ps.quantity,
          'order_id'=>order.id,
          'ord_ord_num'=>export_field(:ord_ord_num,order),
          'ord_cust_ord_no'=>export_field(:ord_cust_ord_no,order)
        }
        line_fields = limit_fields([
          :ordln_line_number,
          :ordln_puid,
          :ordln_pname,
          :ordln_ppu,
          :ordln_currency,
          :ordln_ordered_qty,
          :ordln_country_of_origin,
          :ordln_hts
        ] + custom_field_keys(CoreModule::ORDER_LINE))
        line_fields.each {|uid| olh[uid] = export_field(uid,ol)}
        olh
      else
        nil
      end
    end
  end
  def load_lines shipment, h
    if h['lines']
      h['lines'].each_with_index do |ln,i|
        s_line = shipment.shipment_lines.find {|obj| match_numbers?(ln['id'], obj.id) || match_numbers?(ln['shpln_line_number'], obj.line_number)}
        s_line = shipment.shipment_lines.build(line_number:ln['cil_line_number']) if s_line.nil?
        if ln['_destroy']
          s_line.mark_for_destruction
          next
        end
        import_fields ln, s_line, CoreModule::SHIPMENT_LINE
        if ln['linked_order_line_id']
          o_line = OrderLine.find_by_id ln['linked_order_line_id']
          shipment.errors[:base] << "Order line #{ln['linked_order_line_id']} not found." unless o_line && o_line.can_view?(current_user)
          s_line.product = o_line.product if s_line.product.nil?
          shipment.errors[:base] << "Order line #{o_line.id} does not have the same product as the shipment line provided (#{s_line.product.unique_identifier})" unless s_line.product == o_line.product
          s_line.linked_order_line_id = ln['linked_order_line_id']
        end
        shipment.errors[:base] << "Product required for shipment lines." unless s_line.product
        shipment.errors[:base] << "Product not found." if s_line.product && !s_line.product.can_view?(current_user)
        shipment.errors[:base] << "Line #{i+1} is missing #{ModelField.find_by_uid(:shpln_line_number).label}." if s_line.line_number.blank?
      end
    end
  end
  def load_containers shipment, h
    if h['containers']
      h['containers'].each_with_index do |ln,i|
        con = shipment.containers.find {|obj| match_numbers? ln['id'], obj.id}
        con = shipment.containers.build if con.nil?
        if ln['_destroy']
          if con.shipment_lines.empty?
            con.mark_for_destruction
            next
          else
            shipment.errors[:base] << "Cannot delete container linked to shipment lines."
          end
        end
        import_fields ln, con, CoreModule::CONTAINER
      end
    end
  end

  def match_numbers? hash_val, number
    return !hash_val.blank? && hash_val.to_s == number.to_s
  end
end; end; end