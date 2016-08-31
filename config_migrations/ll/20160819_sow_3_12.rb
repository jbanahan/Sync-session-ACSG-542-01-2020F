require 'csv'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigration; module LL; class SOW312
  DEFS ||= [
    :ordln_pc_approved_by,
    :ordln_pc_approved_date,
    :ordln_pc_approved_by_executive,
    :ordln_pc_approved_date_executive,
    :ordln_qa_approved_by,
    :ordln_qa_approved_date
  ]
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  def up
    cdefs = self.class.prep_custom_definitions DEFS
    disable_unaccept_notifications
    update_orders cdefs
    drain_delayed_jobs
    accept_orders_again cdefs
    enable_unaccept_notifications
  end
  def down
  end

  def update_orders cdefs
    f = File.new('tmp/sow312.csv','w')
    begin
      u = User.integration
      all_orders = Order.
        where('closed_at is null').
        where('orders.id IN (select order_id from order_lines where unit_of_measure IN ("FTK","FOT"))').
        includes(:order_lines)
      all_orders.find_each do |o|
        write_accepted_record(o,f,cdefs)
        o.order_lines.each {|ol| ol.unit_of_measure = convert_uom(ol.unit_of_measure); ol.save!}
        o.create_snapshot u
      end
    ensure
      f.close
    end
  end

  def accept_orders_again cdefs
    u = User.integration
    rows_by_order = Hash.new { |hash, key| hash[key] = []}
    CSV.foreach('tmp/sow312.csv') do |row|
      rows_by_order[row[0]] << row
    end
    rows_by_order.each do |order_id,rows|
      row = rows.first
      o = Order.find row[0]
      o.approval_status = row[1]
      o.accepted_by_id = row[2] unless row[2].blank?
      unless row[3].blank?
        o.accepted_at = DateTime.iso8601(row[3])
      end
      rows.each do |r|
        ol = o.order_lines.find {|line| line.id.to_s == r[4]}
        DEFS.each_with_index do |d,idx|
          v = r[idx+5]
          next if v.blank?
          v = DateTime.iso8601(v) if cdefs[d].data_type=='datetime'
          ol.update_custom_value!(cdefs[d],v)
        end
      end
      o.save!
      o.create_snapshot u
    end
  end

  def drain_delayed_jobs
    while Delayed::Job.count > 0
      puts "Sleeping 5 while Delayed Jobs drain."
      sleep 5
    end
  end

  def disable_unaccept_notifications
    EventSubscription.where(event_type:'ORDER_UNACCEPT').update_all(system_message:false)
  end

  def enable_unaccept_notifications
    EventSubscription.where(event_type:'ORDER_UNACCEPT').update_all(system_message:true)
  end

  def write_accepted_record o, f, cdefs
    o.order_lines.each do |ol|
      accepted_at = o.accepted_at ? o.accepted_at.iso8601 : ''
      row = [o.id,o.approval_status,o.accepted_by_id,accepted_at,ol.id]
      DEFS.each do |d|
        cd = cdefs[d]
        v = ol.custom_value(cd)
        if cd.data_type == 'datetime' && !v.blank?
          v = v.iso8601
        end
        v = '' if v.nil?
        row << v
      end
      f << row.to_csv
    end
  end

  def convert_uom str
    vals = {'FTK'=>'FT2','FOT'=>'FT'}
    new_str = vals[str]
    new_str.blank? ? str : new_str
  end


end; end; end
