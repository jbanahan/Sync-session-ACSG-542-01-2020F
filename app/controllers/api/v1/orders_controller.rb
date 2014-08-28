module Api; module V1; class OrdersController < Api::V1::ApiController
  def core_module
    CoreModule::ORDER
  end
  def index
    render_search CoreModule::ORDER
  end

  def show
    render_show CoreModule::ORDER
  end

  def obj_to_json_hash o
    headers_to_render = limit_fields([
      :ord_ord_num,
      :ord_cust_ord_no,
      :ord_imp_name,
      :ord_imp_syscode,
      :ord_mode,
      :ord_ord_date,
      :ord_ven_name,
      :ord_ven_syscode
    ] + custom_field_keys(CoreModule::ORDER))
    line_fields_to_render = limit_fields([
      :ordln_line_number,
      :ordln_puid,
      :ordln_pname,
      :ordln_ppu,
      :ordln_currency,
      :ordln_ordered_qty,
      :ordln_country_of_origin,
      :ordln_hts,
      :ordln_sku
    ] + custom_field_keys(CoreModule::ORDER_LINE))
    h = {id:o.id}
    headers_to_render.each {|uid| h[uid] = export_field(uid,o)}
    o.order_lines.each do |ol|
      h['lines'] ||= []
      olh = {id: ol.id}
      line_fields_to_render.each {|uid| olh[uid] = export_field(uid,ol)}
      h['lines'] << olh
    end
    h
  end
end; end; end