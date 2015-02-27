module Api; module V1; class ShipmentsController < Api::V1::ApiCoreModuleControllerBase
  include ActionView::Helpers::NumberHelper

  def initialize
    super(OpenChain::Api::ApiEntityJsonizer.new(force_big_decimal_numeric:true, blank_if_nil:true))
  end

  def core_module
    CoreModule::SHIPMENT
  end
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

  def available_orders
    s = Shipment.find params[:id]
    raise StatusableError.new("Shipment not found.",404) unless s.can_view?(current_user)
    ord_fields = [:ord_ord_num,:ord_cust_ord_no,:ord_mode,:ord_imp_name,:ord_ord_date,:ord_ven_name]
    r = []
    s.available_orders(current_user).order('customer_order_number').each do |ord|
      hsh = {id:ord.id}
      ord_fields.each {|uid| hsh[uid] = export_field(uid, ord)}
      r << hsh
    end
    render json: {available_orders:r}
  end

  def process_tradecard_pack_manifest
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to edit this Shipment.",:forbidden) unless s.can_edit?(current_user)
    att = s.attachments.find_by_id(params[:attachment_id])
    raise StatusableError.new("Attachment not linked to Shipment.",400) unless att
    aj = s.attachment_process_jobs.where(attachment_id:att.id,
          job_name:'Tradecard Pack Manifest').first_or_create!(user_id:current_user.id)
    if aj.start_at
      raise StatusableError.new("This manifest has already been submitted for processing.",400)
    else
      aj.update_attributes(start_at:Time.now)
      aj.process
      render_show CoreModule::SHIPMENT
    end
  end

  def request_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to request a booking.",:forbidden) unless s.can_request_booking?(current_user)
    s.async_request_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def approve_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to approve a booking.",:forbidden) unless s.can_approve_booking?(current_user)
    s.async_approve_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def confirm_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to confirm a booking.",:forbidden) unless s.can_confirm_booking?(current_user)
    s.async_confirm_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def revise_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to revise this booking.",:forbidden) unless s.can_revise_booking?(current_user)
    s.async_revise_booking! current_user
    render json: {'ok'=>'ok'}
  end

  def cancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to cancel this booking.",:forbidden) unless s.can_cancel?(current_user)
    s.async_cancel_shipment! current_user
    render json: {'ok'=>'ok'}
  end

  def uncancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to undo canceling this booking.",:forbidden) unless s.can_uncancel?(current_user)
    s.async_uncancel_shipment! current_user
    render json: {'ok'=>'ok'}
  end

  def save_object h
    shp = h['id'].blank? ? Shipment.new : Shipment.includes([
      {shipment_lines: [:piece_sets,{custom_values:[:custom_definition]},:product]},
      :containers,
      {custom_values:[:custom_definition]}
    ]).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if shp.nil?
    shp = freeze_custom_values shp, false #don't include order fields
    import_fields h, shp, CoreModule::SHIPMENT
    load_containers shp, h
    load_carton_sets shp, h
    load_lines shp, h
    raise StatusableError.new("You do not have permission to save this Shipment.",:forbidden) unless shp.can_edit?(current_user)
    shp.save if shp.errors.full_messages.blank?
    shp

  end
  def obj_to_json_hash s
    headers_to_render = limit_fields([
      :shp_ref,
      :shp_importer_reference,
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
      :shp_delivered_date,
      :shp_comment_count,
      :shp_dest_port_name,
      :shp_dest_port_id,
      :shp_cargo_ready_date,
      :shp_booking_requested_by_full_name,
      :shp_booking_confirmed_by_full_name,
      :shp_booking_approved_by_full_name,
      :shp_booking_approved_date,
      :shp_booked_quantity,
      :shp_canceled_by_full_name,
      :shp_canceled_date
    ] + custom_field_keys(CoreModule::SHIPMENT))

    line_fields_to_render = limit_fields([
      :shpln_line_number,
      :shpln_shipped_qty,
      :shpln_puid,
      :shpln_pname,
      :shpln_container_uid,
      :shpln_container_number,
      :shpln_container_size,
      :shpln_cbms,
      :shpln_gross_kgs,
      :shpln_carton_qty,
      :shpln_carton_set_uid
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
      :con_uom,
      :con_shipment_line_count
    ] + custom_field_keys(CoreModule::CONTAINER))

    h = {id: s.id}
    headers_to_render.each {|uid| h[uid] = export_field(uid, s)}
    if render_lines?
      h['lines'] ||= []
      s.shipment_lines.each do |sl|
        slh = {id: sl.id}
        line_fields_to_render.each {|uid| slh[uid] = export_field(uid, sl)}
        if render_order_fields?
          slh['order_lines'] = render_order_fields(sl)
        end
        h['lines'] << slh
      end
    end
    s.containers.each do |c|
      h['containers'] ||= []
      ch = {id: c.id}
      container_fields_to_render.each {|uid| ch[uid] = export_field(uid, c)}
      h['containers'] << ch
    end
    if render_carton_sets?
      h['carton_sets'] = render_carton_sets(s)
    end
    if render_attachments?
      render_attachments(s,h)
    end
    if render_summary?
      h['summary'] = render_summary(s)
    end
    h['permissions'] = render_permissions(s)
    h
  end

  #override api_controller method to pre-load lines
  def find_object_by_id id
    includes_array = [
      {shipment_lines: [:piece_sets,:custom_values,:product]},
      :containers,
      :custom_values
    ]
    includes_array[0][:shipment_lines][0] = {piece_sets: {order_line: [:custom_values, :product, :order]}} if render_order_fields?
    s = Shipment.where(id:id).includes(includes_array).first
    s = freeze_custom_values s, render_order_fields?
    s
  end
  private
  def render_permissions shipment
    {
      can_edit:shipment.can_edit?(current_user),
      can_view:shipment.can_view?(current_user),
      can_attach:shipment.can_attach?(current_user),
      can_comment:shipment.can_comment?(current_user),
      can_request_booking:shipment.can_request_booking?(current_user),
      can_approve_booking:shipment.can_approve_booking?(current_user),
      can_confirm_booking:shipment.can_confirm_booking?(current_user),
      can_revise_booking:shipment.can_revise_booking?(current_user),
      can_add_remove_lines:shipment.can_add_remove_lines?(current_user),
      can_cancel:shipment.can_cancel?(current_user),
      can_uncancel:shipment.can_uncancel?(current_user)
    }
  end
  def render_lines?
    params[:no_lines].blank?
  end
  def render_carton_sets?
    params[:include] && params[:include].match(/carton_sets/)
  end
  def render_carton_sets shipment
    fields = limit_fields([
      :cs_starting_carton,
      :cs_carton_qty,
      :cs_length,
      :cs_width,
      :cs_height,
      :cs_net_net,
      :cs_net,
      :cs_gross
    ])
    return shipment.carton_sets.collect do |cs|
      ch = {id:cs.id}
      fields.each {|uid| ch[uid] = export_field(uid, cs)}
      ch
    end
  end
  def render_summary?
    params[:summary]
  end
  def render_summary shipment
    piece_count = 0
    order_ids = Set.new
    product_ids = Set.new
    shipment.shipment_lines.each do |sl|
      piece_count += sl.quantity unless sl.quantity.nil?
      sl.order_lines.each {|ol| order_ids << ol.order_id}
      product_ids << sl.product_id
    end
    {
      line_count: number_with_delimiter(shipment.shipment_lines.count),
      piece_count: number_with_delimiter(number_with_precision(piece_count, strip_insignificant_zeros:true)),
      order_count: number_with_delimiter(order_ids.to_a.compact.size),
      product_count: number_with_delimiter(product_ids.to_a.compact.size)
    }
  end
  def render_order_fields?
    params[:include] && params[:include].match(/order_lines/)
  end
  #return hash with extra order line fields
  def render_order_fields shipment_line
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
        line_fields.each {|uid| olh[uid] = export_field(uid, ol)}
        olh
      else
        nil
      end
    end
  end
  def load_lines shipment, h
    if h['lines']
      h['lines'].each_with_index do |base_ln,i|
        ln = base_ln.clone
        if !ln['shpln_puid'].blank? && !ln['shpln_pname'].blank?
          ln.delete 'shpln_pname' #dont' need to update for both
        end
        s_line = shipment.shipment_lines.find {|obj| match_numbers?(ln['id'], obj.id) || match_numbers?(ln['shpln_line_number'], obj.line_number)}
        if s_line.nil?
          raise StatusableError.new("You cannot add lines to this shipment.",400) unless shipment.can_add_remove_lines?(current_user)
          s_line = shipment.shipment_lines.build(line_number:ln['cil_line_number'])
        end
        if ln['_destroy']
          raise StatusableError.new("You cannot remove lines from this shipment.",400) unless shipment.can_add_remove_lines?(current_user)
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
        # shipment.errors[:base] << "Line #{i+1} is missing #{ModelField.find_by_uid(:shpln_line_number).label}." if s_line.line_number.blank?
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

  def load_carton_sets shipment, h
    if h['carton_sets']
      h['carton_sets'].each do |ln|
        cs = shipment.carton_sets.find {|obj| match_numbers? ln['id'], obj.id}
        cs = shipment.carton_sets.build if cs.nil?
        if ln['_destroy']
          if cs.shipment_lines.empty?
            cs.mark_for_destruction
            next
          else
            shipment.errors[:base] << "Cannot delete carton set linked to shipment lines."
          end
        end
        import_fields ln, cs, CoreModule::CARTON_SET
      end
    end
  end

  def match_numbers? hash_val, number
    return !hash_val.blank? && hash_val.to_s == number.to_s
  end

  def freeze_custom_values s, include_order_lines
    #force the internal cache of custom values for so the
    #get_custom_value methods don't double check the DB for missing custom values
    if s
      s.freeze_custom_values
      s.shipment_lines.each {|sl|
        sl.freeze_custom_values
        if sl.product
          sl.product.freeze_custom_values
        end

        if include_order_lines
          sl.piece_sets.each {|ps|
            ol = ps.order_line
            if ol
              ol.freeze_custom_values
              if ol.product
                ol.product.freeze_custom_values
              end
            end
          }
        end
      }
    end
    s
  end
end; end; end
