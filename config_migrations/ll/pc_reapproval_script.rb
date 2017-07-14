require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'

class LlPcReapprovalScript

  def initialize
    @cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions [:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive]
    @cdef_uids = {}
    @cdefs.each {|k,v| @cdef_uids[k] = v.model_field_uid}
    @integration = User.integration
  end

  def run source_file, snapshot_comment
    File.open("tmp/log-#{Time.now.to_i}.txt",'wb') do |f|
      orders_processed = []
      order_numbers = CSV.read(source_file).collect {|line| line.first}
      order_numbers.in_groups_of(200,false) do |ord_nums|
        Order.where("order_number in (?)",ord_nums).includes({:order_lines=>:custom_values}).each do |ord|
          process_order ord, f, snapshot_comment
          orders_processed << ord.order_number
        end
      end
      orders_not_processed = order_numbers - orders_processed
      f << "These orders were not found in the database: #{orders_not_processed}\n" unless orders_not_processed.empty?
    end
  end

  def process_order order, log_file, snapshot_comment
    unapproved_lines = get_unapproved_lines(order)
    lines_approved = []
    if unapproved_lines.blank?
      log_file << "Order #{order.order_number} is already fully approved, skipping.\n"
      return
    end
    order.entity_snapshots.order('entity_snapshots.id desc').each do |es|
      process_snapshot(unapproved_lines,lines_approved,es)
      break if unapproved_lines.blank?
    end
    if !lines_approved.empty?
      log_file << "Order #{order.order_number} approved lines #{lines_approved.collect {|ol| ol.line_number}.join(", ")}\n"
      order.create_snapshot @integration, nil, snapshot_comment
    end
  end

  def process_snapshot unapproved_lines, lines_approved, es
    children = es.snapshot_hash['entity']['children']
    return unless children
    line_hashes = children.find_all {|child| child['entity']['core_module']=='OrderLine'}

    unapproved_lines.delete_if do |ul|
      r_val = false
      my_line_hash = line_hashes.find {|ch| ch['entity']['model_fields']['ordln_line_number']==ul.line_number}
      if my_line_hash
        approved_date, approved_by, is_exec = get_approvals(my_line_hash)
        if approved_date # found an approval to apply
          apply_approval(approved_date,approved_by,is_exec,ul)
          lines_approved << ul
          r_val = true
        end
      end
      r_val
    end
  end

  def apply_approval approved_date, approved_by, is_exec, ol
    date_id = is_exec ? :ordln_pc_approved_date_executive : :ordln_pc_approved_date
    by_id = is_exec ? :ordln_pc_approved_by_executive : :ordln_pc_approved_by
    ol.update_custom_value!(@cdefs[date_id],approved_date)
    ol.update_custom_value!(@cdefs[by_id],approved_by)
  end

  def get_approvals myh
    my_line_hash = myh['entity']['model_fields']
    approved_date_to_use = nil
    approved_by_to_use = nil
    is_exec = false
    if my_line_hash[@cdef_uids[:ordln_pc_approved_date]]
      approved_date_to_use = my_line_hash[@cdef_uids[:ordln_pc_approved_date]]
      approved_by_to_use = my_line_hash[@cdef_uids[:ordln_pc_approved_by]]
    end
    if my_line_hash[@cdef_uids[:ordln_pc_approved_date_executive]]
      approved_date_to_use = my_line_hash[@cdef_uids[:ordln_pc_approved_date_executive]]
      approved_by_to_use = my_line_hash[@cdef_uids[:ordln_pc_approved_by_executive]]
      is_exec = true
    end
    [approved_date_to_use,approved_by_to_use,is_exec]
  end

  def get_unapproved_lines order
    r = []
    order.order_lines.each do |ol|
      r << ol if ol.custom_value(@cdefs[:ordln_pc_approved_date]).blank? && ol.custom_value(@cdefs[:ordln_pc_approved_date_executive]).blank?
    end
    return r
  end
end
