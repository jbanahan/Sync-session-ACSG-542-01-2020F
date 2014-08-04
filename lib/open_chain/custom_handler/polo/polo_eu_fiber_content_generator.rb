require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class PoloEuFiberContentGenerator < ProductGenerator

  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  SYNC_CODE ||= 'eu_fiber_content'

  def self.run_schedulable opts={}
    self.new(opts).generate
  end
  
  def initialize opts={}
    super(opts)
    @cdefs = self.class.prep_custom_definitions [:merch_division,:fiber_content,:csm_numbers]
  end

  def generate
    c = Company.where(master:true).first
    u = c.users.where(username:'EU Fiber Content').first
    if u.nil?
     u = c.users.build(username:'EU Fiber Content',first_name:'EU',last_name:'Fiber Content',product_view:true,email:'bug@vandegriftinc.com')
     u.password = '128ufj8sdf812i'
     u.save!
    end
    f = sync_xls
    if f
      OpenMailer.send_simple_html(u.email,'VFI Track EU Fiber Content Report','Fiber content report is attached.',f).deliver!
    end
    nil
  end

  def sync_code
    SYNC_CODE
  end

  def trim_fingerprint row
    [row[3],row]
  end

  def auto_confirm?
    true
  end

  def query
    q = <<QRY
SELECT products.id, products.unique_identifier as 'US Style',
products.name as 'Name',
(SELECT string_value FROM custom_values WHERE custom_values.custom_definition_id = #{@cdefs[:fiber_content].id} AND custom_values.customizable_id = products.id) as 'Fiber Content',
(SELECT hts_1 FROM tariff_records INNER JOIN classifications ON classifications.id = tariff_records.classification_id AND classifications.country_id = (SELECT id from countries WHERE countries.iso_code = 'IT') WHERE classifications.product_id = products.id ORDER BY tariff_records.line_number LIMIT 1) as 'IT HTS',
(SELECT text_value FROM custom_values WHERE custom_values.custom_definition_id = #{@cdefs[:csm_numbers].id} AND custom_values.customizable_id = products.id) as 'CSM',
(SELECT string_value FROM custom_values WHERE custom_values.custom_definition_id = #{@cdefs[:merch_division].id} AND custom_values.customizable_id = products.id) as 'Merch Division'
FROM products
#{Product.need_sync_join_clause(SYNC_CODE)}
QRY
    w = " WHERE products.updated_at >= DATE_ADD(now(),INTERVAL -30 DAY) AND #{Product.need_sync_where_clause()} AND (sync_records.fingerprint is null OR sync_records.fingerprint = '' OR sync_records.fingerprint <> (SELECT string_value FROM custom_values WHERE custom_values.custom_definition_id = #{@cdefs[:fiber_content].id} AND custom_values.customizable_id = products.id)) AND length((SELECT string_value FROM custom_values WHERE custom_values.custom_definition_id = #{@cdefs[:fiber_content].id} AND custom_values.customizable_id = products.id)) > 0 AND length((SELECT hts_1 FROM tariff_records INNER JOIN classifications ON classifications.id = tariff_records.classification_id AND classifications.country_id = (SELECT id from countries WHERE countries.iso_code = 'IT') WHERE classifications.product_id = products.id ORDER BY tariff_records.line_number LIMIT 1)) > 0 "
    q << (@custom_where ? @custom_where : w)
    q << " LIMIT 65000"
  end
end; end; end; end