require 'open_chain/s3'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/order_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_pdf_generator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/custom_handler/lumber_liquidators/lumber_autoflow_order_approver'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderChangeComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::EntityCompare::OrderComparator

  ORDER_MODEL_FIELDS ||= [:ord_ord_num,:ord_window_start,:ord_window_end,:ord_currency,:ord_payment_terms,:ord_terms]
  ORDER_LINE_MODEL_FIELDS ||= [:ordln_line_number,:ordln_puid,:ordln_ordered_qty,:ordln_unit_of_measure,:ordln_ppu]
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Order'
    if old_bucket.nil?
      run_changes type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    else
      old_fingerprint = get_fingerprint(old_bucket, old_path, old_version)
      new_fingerprint = get_fingerprint(new_bucket, new_path, new_version)
      if old_fingerprint!=new_fingerprint
        run_changes type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
        compare_lines(id,new_fingerprint,old_fingerprint)
      end
    end
    o = Order.find_by_id(id)
    if o
      OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.process(o)
    end
  end

  def self.run_changes type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    o = Order.find id
    u = User.integration
    o.unaccept! u if !o.approval_status.blank?
    OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.create! o, u
  end

  def self.compare_lines order_id, new_fingerprint, old_fingerprint
    new_lh = fingerprint_to_line_hash(new_fingerprint)
    old_lh = fingerprint_to_line_hash(old_fingerprint)

    lines_to_run = new_lh.keys - old_lh.keys
    (new_lh.keys & old_lh.keys).each do |common_line_number|
      lines_to_run << common_line_number if new_lh[common_line_number] != old_lh[common_line_number]
    end
    if !lines_to_run.empty?
      cdefs = self.prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
      lines_to_run.each {|line_number| run_line_changes(order_id,line_number,cdefs)}
    end
  end
  def self.run_line_changes order_id, line_number, cdefs = self.prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
    ol = OrderLine.where(order_id:order_id,line_number:line_number).first
    return unless ol
    cdefs.values.each do |cd|
      ol.update_custom_value!(cd,nil)
    end
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
          prefix = uid==:ordln_line_number ? '~' : '' #double tilde to start each order line in fingerprint
          elements << "#{prefix}#{child_hash[uid.to_s]}"
        end
      end
    end
    elements.join('~')
  end

  def self.get_fingerprint bucket, path, version
    fingerprint(get_json_hash(bucket,path,version))
  end

  def self.fingerprint_to_line_hash fp
    lines = fp.split('~~')
    lines.shift
    r = {}
    lines.each do |ln|
      r[ln.split('~').first] = ln
    end
    return r
  end
  private_class_method :fingerprint_to_line_hash
end; end; end; end
