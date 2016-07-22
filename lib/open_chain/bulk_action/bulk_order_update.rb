module OpenChain; module BulkAction; class BulkOrderUpdate

  def self.bulk_type
    'Bulk Order Update'
  end

  def self.act user, id, opts, bulk_process_log, sequence
    ord = Order.find id
    if ord.can_edit? user
      fields_to_update = compile_field_list user, opts
      assign_fields(fields_to_update, ord, user, opts)
      ord.save!
      ord.create_snapshot user
      bulk_process_log.change_records.create!(recordable: ord, record_sequence_number: sequence, failed: false)
    else
      cr = bulk_process_log.change_records.create!(recordable: ord, record_sequence_number: sequence, failed: true)
      cr.add_message "You do not have permission to update the order with ID #{id}."
    end
  end

  private

  def self.assign_fields mf_list, ord, user, opts
    mf_list.each_pair { |mf_id, mf| mf.process_import(ord, opts[mf_id.to_s], user) }
  end

  def self.compile_field_list user, opts
    CoreModule::ORDER.model_fields(user) { |mf| opts.keys.include?(mf.uid.to_s) && mf.can_view?(user) }
  end

end; end; end