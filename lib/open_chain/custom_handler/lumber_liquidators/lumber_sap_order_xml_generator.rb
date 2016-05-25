require 'open_chain/api/api_entity_xmlizer'
require 'open_chain/ftp_file_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapOrderXmlGenerator
  include OpenChain::FtpFileSupport
  def self.send_order order
    xml = generate(User.integration,order)
    Tempfile.open(['po_','.xml']) do |tf|
      tf.write xml
      tf.flush
      ftp_file tf
    end
  end

  def self.ftp_credentials
    folder = "ll-edi/#{Rails.env.production? && MasterSetup.get.system_code=='ll' ? 'prod' : 'test'}/to-ll/po"
    ecs_connect_vfitrack_net(folder)
  end

  def self.generate user, order
    f = build_field_list(user)
    OpenChain::Api::ApiEntityXmlizer.new.entity_to_xml(user,order,f)
  end

  def self.build_field_list current_user
    f = [
      :ord_ord_num,
      :ord_cust_ord_no,
      :ord_imp_name,
      :ord_imp_syscode,
      :ord_mode,
      :ord_ord_date,
      :ord_ven_name,
      :ord_ven_syscode,
      :ord_window_start,
      :ord_window_end,
      :ord_first_exp_del,
      :ord_fob_point,
      :ord_currency,
      :ord_payment_terms,
      :ord_terms,
      :ord_total_cost,
      :ord_approval_status,
      :ord_order_from_address_name,
      :ord_order_from_address_full_address,
      :ord_ship_to_count,
      :ord_ship_from_id,
      :ord_ship_from_full_address,
      :ord_ship_from_name,
      :ord_rule_state,
      :ord_closed_at,
      :ordln_line_number,
      :ordln_puid,
      :ordln_pname,
      :ordln_ppu,
      :ordln_currency,
      :ordln_ordered_qty,
      :ordln_country_of_origin,
      :ordln_hts,
      :ordln_sku,
      :ordln_unit_of_measure,
      :ordln_total_cost,
      :ordln_ship_to_full_address
    ]
    [CoreModule::ORDER,CoreModule::ORDER_LINE].each do |cm|
      f += cm.model_fields(current_user) {|mf| mf.custom? }.keys
    end
    f
  end
end; end; end; end
