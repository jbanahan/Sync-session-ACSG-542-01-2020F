require 'open_chain/s3'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_pdf_generator'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderChangeComparator
  ORDER_MODEL_FIELDS ||= [:ord_ord_num,:ord_window_start,:ord_window_end,:ord_currency,:ord_payment_terms,:ord_terms]
  ORDER_LINE_MODEL_FIELDS ||= [:ordln_line_number,:ordln_puid,:ordln_ordered_qty,:ordln_unit_of_measure,:ordln_ppu]
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Order'
    run = false
    run = true if old_bucket.nil?
    run = true if !run && fingerprints_different?(old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    if run
      run_changes type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    end
  end

  def self.run_changes type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    o = Order.find id
    o.unaccept! User.integration
    OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.create! o
  end

  def self.fingerprint entity_hash
    elements = []
    order_hash = entity_hash['entity']['model_fields']
    ORDER_MODEL_FIELDS.each do |uid|
      elements << order_hash[uid.to_s]
    end
    if entity_hash['entity']['children']
      entity_hash['entity']['children'].each do |child|
        next unless child['entity']['core_module'] == 'OrderLine'
        child_hash = child['entity']['model_fields']
        ORDER_LINE_MODEL_FIELDS.each do |uid|
          elements << child_hash[uid.to_s]
        end
      end
    end
    elements.join('~')
  end

  def self.get_json_hash bucket, key, version
    JSON.parse OpenChain::S3.get_versioned_data(bucket, key, version)
  end

  def self.fingerprints_different? old_bucket, old_path, old_version, new_bucket, new_path, new_version
    old_hash = get_json_hash(old_bucket,old_path,old_version)
    new_hash = get_json_hash(new_bucket,new_path,new_version)
    old_fingerprint = fingerprint(old_hash)
    new_fingerprint = fingerprint(new_hash)

    old_fingerprint!=new_fingerprint    
  end
  private_class_method :fingerprints_different?
end; end; end; end