module Api; module V1; class ShipmentsController < Api::V1::ApiController
  def index
    render_search CoreModule::SHIPMENT
  end

  def show
    render_show CoreModule::SHIPMENT
  end

  def obj_to_json_hash s
    headers_to_render = [
      :shp_ref,
      :shp_mode,
      :shp_ven_name,
      :shp_ven_syscode,
      :shp_ship_to_name,
      :shp_ship_from_name,
      :shp_car_name,
      :shp_car_syscode
    ] + custom_field_keys(CoreModule::SHIPMENT)

    line_fields_to_render = [
      :shpln_line_number,
      :shpln_shipped_qty,
      :shpln_puid,
      :shpln_pname,
      :shpln_container_uid,
      :shpln_container_number,
      :shpln_container_size
    ] + custom_field_keys(CoreModule::SHIPMENT_LINE)

    container_fields_to_render = [
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
    ] + custom_field_keys(CoreModule::CONTAINER)
    
    h = {id: s.id}
    headers_to_render.each {|uid| h[uid] = ModelField.find_by_uid(uid).process_export(s,current_user)}
    s.shipment_lines.each do |sl|
      h['lines'] ||= []
      slh = {id: sl.id}
      line_fields_to_render.each {|uid| slh[uid] = ModelField.find_by_uid(uid).process_export(sl,current_user)}
      h['lines'] << slh
    end
    s.containers.each do |c|
      h['containers'] ||= []
      ch = {id: c.id}
      container_fields_to_render.each {|uid| ch[uid] = ModelField.find_by_uid(uid).process_export(c,current_user)}
      h['containers'] << ch
    end
    h
  end
end; end; end