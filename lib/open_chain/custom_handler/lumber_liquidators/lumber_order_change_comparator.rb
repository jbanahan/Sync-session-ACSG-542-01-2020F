require 'open_chain/s3'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/order_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_default_value_setter'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_pdf_generator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/custom_handler/lumber_liquidators/lumber_autoflow_order_approver'
require 'open_chain/custom_handler/lumber_liquidators/lumber_sap_order_xml_generator'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderChangeComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::EntityCompare::OrderComparator

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Order'
    old_data = build_order_data(old_bucket,old_path,old_version)
    new_data = build_order_data(new_bucket,new_path,new_version)
    execute_business_logic(id,old_data,new_data)
  end

  def self.build_order_data bucket, path, version
    return nil if bucket.blank?
    h = get_json_hash(bucket,path,version)
    OrderData.build_from_hash(h)
  end

  def self.execute_business_logic id, old_data, new_data
    ord = Order.find_by_id id
    return unless ord

    # ordering of these calls matters to the logical flow
    defaults_changed = false
    if set_defaults ord, new_data
      ord.reload
      defaults_changed = true
    end
    ord.reload if reset_vendor_approvals ord, old_data, new_data
    ord.reload if reset_product_compliance_approvals ord, old_data, new_data
    ord.reload if update_autoflow_approvals ord

    generate_ll_xml(ord,old_data,new_data)

    # if we changed the default values then the PDF should be generated from the comparator
    # that is triggered by that snapshot.  Otherwise, we'll get 2 PDFs.
    #
    # we don't need to worry about this for reset_vendor_approvals, reset_product_compliance_approvals,
    # and update_autoflow_approvals since those don't change the fingerprint, so their snapshots won't
    # try to create a new PDF
    create_pdf(ord,old_data,new_data) unless defaults_changed
  end


  def self.generate_ll_xml ord, old_data, new_data
    if new_data.planned_handover_date && (old_data.nil? || old_data.planned_handover_date != new_data.planned_handover_date)
      OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator.send_order ord
    end
  end

  # set default values based on the vendor setup if they're blank
  def self.set_defaults ord, new_data
    return new_data.has_blank_defaults? && OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter.set_defaults(ord)
  end

  def self.update_autoflow_approvals ord
    return OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.process(ord)
  end

  def self.reset_vendor_approvals ord, old_data, new_data
    if OrderData.vendor_approval_reset_fields_changed?(old_data, new_data) && !ord.approval_status.blank?
      ord.unaccept! User.integration
      return true
    end
    return false
  end

  def self.reset_product_compliance_approvals ord, old_data, new_data
    cdefs = prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
    values_changed = false
    lines_to_check = OrderData.lines_needing_pc_approval_reset(old_data,new_data)
    lines_to_check.each do |line_number|
      ol = ord.order_lines.find_by_line_number(line_number)
      next unless ol
      cdefs.values.each do |cd|
        if !ol.get_custom_value(cd).value.blank?
          ol.update_custom_value!(cd,nil)
          values_changed = true
        end
      end
    end
    ord.reload
    ord.create_snapshot(User.integration) if values_changed
    return values_changed
  end

  def self.create_pdf ord, old_data, new_data
    if OrderData.needs_new_pdf?(old_data,new_data)
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.create!(ord, User.integration)
      return true
    end
    return false
  end

  class OrderData
    ORDER_MODEL_FIELDS ||= [:ord_ord_num,:ord_window_start,:ord_window_end,:ord_currency,:ord_payment_terms,:ord_terms,:ord_fob_point]
    ORDER_CUSTOM_FIELDS ||= []
    ORDER_LINE_MODEL_FIELDS ||= [:ordln_line_number,:ordln_puid,:ordln_ordered_qty,:ordln_unit_of_measure,:ordln_ppu]
    # using array so we can dynamically build but not have to
    PLANNED_HANDOVER_DATE_UID ||= []
    include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

    attr_reader :fingerprint
    attr_accessor :ship_from_address, :planned_handover_date

    def initialize fingerprint
      @fingerprint = fingerprint
    end

    def self.build_from_hash entity_hash
      if ORDER_CUSTOM_FIELDS.empty?
        cdefs = prep_custom_definitions([:ord_country_of_origin,:ord_planned_handover_date])
        ORDER_CUSTOM_FIELDS << cdefs[:ord_country_of_origin].model_field_uid.to_sym
        PLANNED_HANDOVER_DATE_UID << cdefs[:ord_planned_handover_date].model_field_uid
      end
      elements = []
      order_hash = entity_hash['entity']['model_fields']
      (ORDER_MODEL_FIELDS + ORDER_CUSTOM_FIELDS).each do |uid|
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
      od = self.new(elements.join('~'))
      od.ship_from_address = order_hash['ord_ship_from_full_address']
      od.planned_handover_date = order_hash[PLANNED_HANDOVER_DATE_UID.first]
      return od
    end

    def has_blank_defaults?
      fingerprint_elements = @fingerprint.split('~')
      return [5,6,7].any? {|pos| fingerprint_elements[pos].blank? }
    end

    def line_hash
      lines = @fingerprint.split('~~')
      lines.shift
      h = {}
      lines.each {|ln| h[ln.split('~').first] = ln}
      h
    end

    def self.vendor_approval_reset_fields_changed? old_data, new_data
      return false if old_data.nil?
      return old_data.fingerprint != new_data.fingerprint
    end

    def self.lines_needing_pc_approval_reset old_data, new_data
      return [] unless old_data

      old_hash = old_data.line_hash
      new_hash = new_data.line_hash

      # if the ship from changed, then all lines need to be re-approved
      return new_hash.keys if old_data.ship_from_address!=new_data.ship_from_address

      lines_to_check = new_hash.keys & old_hash.keys
      lines_to_check.reject {|line_number| old_hash[line_number] == new_hash[line_number]}
    end

    def self.needs_new_pdf? old_data, new_data
      return true if old_data.nil?
      return (old_data.fingerprint != new_data.fingerprint) || (old_data.ship_from_address != new_data.ship_from_address)
    end
  end
end; end; end; end
