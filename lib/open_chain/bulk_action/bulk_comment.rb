module OpenChain; module BulkAction; class BulkComment
  def self.bulk_type
    'Bulk Comment'
  end
  def self.act user, id, opts, bulk_process_log, sequence
    commentable = CoreModule.find_by_class_name(opts['module_type']).klass.find(id)
    if commentable.can_comment?(user)
      subj = opts['subject']
      body = opts['body']
      commentable.comments.create!(subject:subj, body:body, user:user)
      bulk_process_log.change_records.create!(recordable:commentable, record_sequence_number:sequence, failed:false)
    else
      cr = bulk_process_log.change_records.create!(recordable:commentable, record_sequence_number:sequence, failed:true)
      cr.add_message "You do not have permission to comment on the record with ID #{id}."
    end
  end
end; end; end
