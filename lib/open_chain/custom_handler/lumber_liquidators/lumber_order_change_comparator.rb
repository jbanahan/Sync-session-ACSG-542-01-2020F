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

  def self.all_logic_steps
    [:set_defaults, :planned_handover, :forecasted_handover, :vendor_approvals, :compliance_approvals, :autoflow_approvals,
                    :price_revised_dates, :reset_po_cancellation, :update_change_log, :generate_ll_xml]
  end

  def self.execute_business_logic id, old_data, new_data, logic_steps = nil
    ord = Order.find_by_id id
    return unless ord
    Lock.with_lock_retry(ord) do 
      logic_steps = all_logic_steps if logic_steps.blank?
      updated_by = []
      field_updates = false

      Array.wrap(logic_steps).each do |step|
        updated = false
        logic_name = nil
        case step
        when :set_defaults
          logic_name = "Order Default Value Setter"
          updated = set_defaults(ord, new_data)
        when :planned_handover
          logic_name = "Clear Planned Handover"
          updated = clear_planned_handover_date(ord, old_data, new_data)
        when :forecasted_handover
          logic_name = "Forecasted Window Update"
          updated = set_forecasted_handover_date(ord)
        when :vendor_approvals
          logic_name = "Vendor Approval Reset"
          updated = reset_vendor_approvals(ord, old_data, new_data)
        when :compliance_approvals
          logic_name = "Compliance Approval Reset"
          updated = reset_product_compliance_approvals(ord, old_data, new_data)
        when :autoflow_approvals
          logic_name = "Autoflow Order Approver"
          updated = update_autoflow_approvals(ord)
        when :price_revised_dates
          logic_name = "Update Price Revised Dates"
          updated = set_price_revised_dates(ord, old_data, new_data)
        when :reset_po_cancellation
          logic_name = "PO Cancellation Reset"
          updated = reset_po_cancellation(ord)
        when :update_change_log
          logic_name = "Change Log"
          updated = update_change_log(ord,old_data,new_data)
        when :generate_ll_xml
          # Generating XML won't set any order values, so we don't have to do the update handling in here
          generate_ll_xml(ord,old_data,new_data)
        else
          raise "Unexpected logic step of '#{step}' received."
        end

        if updated
          updated_by << logic_name
          field_updates = true
          ord.reload
        end
      end

      if field_updates
        create_pdf(ord,old_data,new_data)
        create_snapshot(ord, User.integration, updated_by)
      end
    end
  end

  def self.create_snapshot order, user, updated_list
    snapshot_context = "System Job: Order Change Comparator: #{updated_list.join " / "}"
    order.create_snapshot user, nil, snapshot_context
  end

  def self.set_price_revised_dates ord, old_data, new_data
    line_ids = OrderData.lines_with_changed_price(old_data,new_data)
    r_val = false
    sap_extract_date = new_data.sap_extract_date
    cdefs = self.prep_custom_definitions([:ord_sap_extract,:ord_price_revised_date,:ordln_price_revised_date])
    line_ids.each do |line_id|
      ol = ord.order_lines.find {|order_line| order_line.line_number==line_id}
      next unless ol
      ol.update_custom_value!(cdefs[:ordln_price_revised_date],sap_extract_date)
      r_val = true
    end
    if r_val
      header_revised_date = ord.custom_value(cdefs[:ord_price_revised_date])
      if !header_revised_date || header_revised_date.to_i < sap_extract_date.to_i
        ord.update_custom_value!(cdefs[:ord_price_revised_date],sap_extract_date)
      end
    end
    return r_val
  end

  def self.clear_planned_handover_date ord, old_data, new_data
    cdefs = self.prep_custom_definitions [:ord_planned_handover_date]
    return false unless ord.custom_value(cdefs[:ord_planned_handover_date])
    if old_data.ship_window_start!=new_data.ship_window_start || old_data.ship_window_end!=new_data.ship_window_end
      ord.update_custom_value!(cdefs[:ord_planned_handover_date],nil)
      return true
    end
    return false
  end

  def self.set_forecasted_handover_date ord
    cdefs = self.prep_custom_definitions [:ord_planned_handover_date,:ord_forecasted_handover_date,:ord_forecasted_ship_window_start]
    current_forecasted_handover_date = ord.custom_value(cdefs[:ord_forecasted_handover_date])
    planned_handover_date = ord.custom_value(cdefs[:ord_planned_handover_date])
    if planned_handover_date && planned_handover_date!=current_forecasted_handover_date
      ord.update_custom_value!(cdefs[:ord_forecasted_handover_date],planned_handover_date)
      ord.update_custom_value!(cdefs[:ord_forecasted_ship_window_start],planned_handover_date-7.days)
      return true
    end
    if !planned_handover_date && ord.ship_window_end && ord.ship_window_end!=current_forecasted_handover_date
      ord.update_custom_value!(cdefs[:ord_forecasted_handover_date],ord.ship_window_end)
      ord.update_custom_value!(cdefs[:ord_forecasted_ship_window_start],ord.ship_window_end-7.days)
      return true
    end
    return false
  end

  def self.generate_ll_xml ord, old_data, new_data
    if OrderData.send_sap_update?(old_data,new_data)
      OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator.send_order ord
    end
  end

  # set default values based on the vendor setup if they're blank
  def self.set_defaults ord, new_data
    return new_data.has_blank_defaults? && OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter.set_defaults(ord, entity_snapshot: false)
  end

  def self.update_autoflow_approvals ord
    return OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.process(ord, entity_snapshot: false)
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
    header_cdef = prep_custom_definitions([:ord_pc_approval_recommendation])[:ord_pc_approval_recommendation]
    values_changed = false
    lines_to_check = OrderData.lines_needing_pc_approval_reset(old_data,new_data)
    lines_to_check.each do |line_number|
      ol = ord.order_lines.find_by_line_number(line_number)
      next unless ol
      cdefs.values.each do |cd|
        if !ol.custom_value(cd).blank?
          ol.update_custom_value!(cd,nil)
          values_changed = true
        end
      end
    end
    if values_changed
      ord.update_custom_value!(header_cdef,'')
    end
    return values_changed
  end

  def self.create_pdf ord, old_data, new_data
    if OrderData.vendor_visible_fields_changed?(old_data,new_data)
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.create!(ord, User.integration)
      return true
    end
    return false
  end

  def self.update_change_log ord, old_data, new_data
    updated_change_log = false
    #don't make change log for first entry
    if old_data && OrderData.vendor_visible_fields_changed?(old_data,new_data)
      change_log_entries = []
      old_fph = old_data.fingerprint_hash
      new_fph = new_data.fingerprint_hash
      old_fph.each do |uid,old_val|
        next if uid.to_s == 'lines'
        new_val = new_fph[uid]
        if new_val != old_val
          change_log_entries << "#{ModelField.find_by_uid(uid).label} changed from \"#{old_val}\" to \"#{new_val}\""
        end
      end
      old_lines = old_fph['lines']
      new_lines = new_fph['lines']
      change_log_entries.push(*make_lines_added_messages(old_lines,new_lines))
      change_log_entries.push(*make_lines_removed_messages(old_lines,new_lines))
      change_log_entries.push(*make_lines_changed_messages(old_lines,new_lines))
      updated_change_log = append_change_log(ord,change_log_entries)
    end
    updated_change_log
  end

  def self.append_change_log ord, new_log_entries
    return false if new_log_entries.blank?

    new_log_entries.each {|nle| nle.prepend("\t")} #indent lines
    cd = self.prep_custom_definitions([:ord_change_log])[:ord_change_log]
    new_log_entries.unshift(0.seconds.ago.utc.strftime('%Y-%m-%d %H:%M (UTC):'))
    current_log = ord.custom_value(cd) || ''
    ord.update_custom_value!(cd,"#{new_log_entries.join("\n")}\n\n#{current_log}")
    true
  end
  private_class_method :append_change_log

  def self.make_lines_added_messages old_lines, new_lines
    new_lines.keys.find_all {|id| !old_lines.keys.include?(id)}.map {|id| "Added line number #{id}"}
  end
  private_class_method :make_lines_added_messages

  def self.make_lines_removed_messages old_lines, new_lines
    old_lines.keys.find_all {|id| !new_lines.keys.include?(id)}.map {|id| "Removed line number #{id}"}
  end
  private_class_method :make_lines_removed_messages

  def self.make_lines_changed_messages old_lines, new_lines
    line_changed_messages = []
    old_lines.each do |k,old_line|
      line_entries = []
      new_line = new_lines[k]
      next unless new_line
      old_line.each do |uid,old_val|
        new_val = new_line[uid]
        if new_val != old_val
          line_entries << "#{ModelField.find_by_uid(uid).label} changed from \"#{old_val}\" to \"#{new_val}\""
        end
      end
      if !line_entries.blank?
        line_changed_messages << "Line #{k}"
        line_entries.each {|ln| line_changed_messages << "\t#{ln}"}
      end
    end
    line_changed_messages
  end
  private_class_method :make_lines_changed_messages

  def self.reset_po_cancellation ord
    ActiveRecord::Base.transaction do
      cdef = prep_custom_definitions([:ord_cancel_date])[:ord_cancel_date]
      cancel_date = ord.custom_value(cdef)
      num_lines = ord.order_lines.length

      if num_lines > 0 && cancel_date
        ord.reopen! User.integration
        ord.update_custom_value!(cdef, nil)
        return true
      elsif num_lines.zero? && cancel_date.nil?
        ord.close! User.integration
        ord.update_custom_value!(cdef, ActiveSupport::TimeZone['America/New_York'].now.to_date)
        return true
      end
      return false
    end
  end

  class OrderData
    ORDER_MODEL_FIELDS ||= [:ord_ord_num,:ord_window_start,:ord_window_end,:ord_currency,:ord_payment_terms,:ord_terms,:ord_fob_point]
    ORDER_LINE_MODEL_FIELDS ||= [:ordln_line_number,:ordln_puid,:ordln_ordered_qty,:ordln_unit_of_measure,:ordln_ppu]
    # using array so we can dynamically build but not have to
    PLANNED_HANDOVER_DATE_UID ||= []
    SAP_EXTRACT_DATE_UID ||= []
    include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

    attr_reader :fingerprint, :fingerprint_hash
    attr_accessor :ship_from_address, :planned_handover_date, :variant_map,
      :ship_window_start, :ship_window_end, :price_map, :sap_extract_date,
      :approval_status, :business_rule_state, :country_of_origin

    def initialize fp_hash
      @fingerprint_hash = fp_hash
      @fingerprint = fp_hash.to_json
      @cdefs = self.class.prep_custom_definitions([:ord_country_of_origin])
    end

    def self.build_from_hash entity_hash
      fingerprint_hash = {'lines'=>{}}
      cdefs = prep_custom_definitions([:ord_country_of_origin,:ord_planned_handover_date,:ord_sap_extract])
      if PLANNED_HANDOVER_DATE_UID.empty?
        PLANNED_HANDOVER_DATE_UID << cdefs[:ord_planned_handover_date].model_field_uid
        SAP_EXTRACT_DATE_UID << cdefs[:ord_sap_extract].model_field_uid
      end
      order_hash = entity_hash['entity']['model_fields']
      ORDER_MODEL_FIELDS.each do |uid|
        fingerprint_hash[uid] = order_hash[uid.to_s]
      end
      variant_map = {}
      price_map = {}
      if entity_hash['entity']['children']
        entity_hash['entity']['children'].each do |child|
          next unless child['entity']['core_module'] == 'OrderLine'
          child_hash = child['entity']['model_fields']
          line_fp_hash = {}
          ORDER_LINE_MODEL_FIELDS.each do |uid|
            line_fp_hash[uid] = child_hash[uid.to_s]
          end
          line_number = child_hash['ordln_line_number']
          fingerprint_hash['lines'][line_number] = line_fp_hash
          variant_map[line_number] = child_hash['ordln_varuid']
          price_map[line_number] = child_hash['ordln_ppu']
        end
      end

      # Create return object
      od = self.new(fingerprint_hash)
      od.ship_window_start = order_hash['ord_window_start']
      od.ship_window_end = order_hash['ord_window_end']
      od.ship_from_address = order_hash['ord_ship_from_full_address']
      od.business_rule_state = order_hash['ord_rule_state']
      od.approval_status = order_hash['ord_approval_status']
      od.planned_handover_date = order_hash[PLANNED_HANDOVER_DATE_UID.first]
      od.country_of_origin = order_hash[cdefs[:ord_country_of_origin].model_field_uid.to_s]
      sap_extract_str = order_hash[SAP_EXTRACT_DATE_UID.first]
      od.sap_extract_date =  sap_extract_str ? DateTime.iso8601(sap_extract_str) : nil
      od.variant_map = variant_map
      od.price_map = price_map
      return od
    end

    def has_blank_defaults?
      return true if ['ord_terms','ord_fob_point'].find {|fld| @fingerprint_hash[fld].blank? }
      return true if self.country_of_origin.blank?
      return false
    end

    def self.vendor_approval_reset_fields_changed? old_data, new_data
      return false if old_data.nil?
      return old_data.fingerprint != new_data.fingerprint
    end

    def self.lines_needing_pc_approval_reset old_data, new_data
      return [] unless old_data

      old_hash = old_data.fingerprint_hash['lines']
      new_hash = new_data.fingerprint_hash['lines']

      # if the ship from changed, then all lines need to be re-approved
      return new_hash.keys if ship_from_changed?(old_data,new_data)

      lines_to_check = new_hash.keys & old_hash.keys
      need_reset = lines_to_check.reject {|line_number| old_hash[line_number] == new_hash[line_number]}
      new_data.variant_map.each do |k,v|
        need_reset << k if old_data.variant_map[k] != v
      end
      need_reset.uniq.compact
    end

    def self.ship_from_changed? old_data, new_data
      osa = old_data.ship_from_address
      nsa = new_data.ship_from_address
      osa = '' if osa.blank?
      nsa = '' if nsa.blank?

      # ignore whitespace differences
      old_address = osa.gsub(/\s/, '')
      new_address = nsa.gsub(/\s/, '')

      return old_address!=new_address
    end

    def self.vendor_visible_fields_changed? old_data, new_data
      return true if old_data.nil?
      return (old_data.fingerprint != new_data.fingerprint) || ship_from_changed?(old_data,new_data)
    end

    def self.lines_with_changed_price old_data, new_data
      nh = new_data.price_map
      oh = old_data ? old_data.price_map : {}
      r_val = []
      nh.each do |k,v|
        r_val << k unless v == oh[k]
      end
      return r_val
    end

    def self.send_sap_update? old_data, new_data
      return true if old_data.nil?
      return true if old_data.planned_handover_date!=new_data.planned_handover_date
      return true if old_data.approval_status!=new_data.approval_status
      return true if old_data.business_rule_state!=new_data.business_rule_state
      return false
    end
  end
end; end; end; end
