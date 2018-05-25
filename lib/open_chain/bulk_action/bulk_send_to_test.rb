module OpenChain; module BulkAction; class BulkSendToTest

  def self.bulk_type
    'Bulk Send to Test'
  end

  def self.act user, id, opts, bulk_process_log, sequence
    # This will blow up with a nil pointer if the module type has not been set properly.  A failure there is actually
    # indicative of improper implementation of BulkSendToTestSupport by a controller (i.e. dev error).  It's
    # intentionally not being handled gracefully.
    obj = CoreModule.find_by_class_name(opts['module_type']).klass.find(id)
    if obj && obj.can_view?(user) && obj.class.respond_to?(:has_last_file?) && obj.has_last_file? && OpenChain::S3.exists?(obj.last_file_bucket, obj.last_file_path)
      obj.class.send_integration_file_to_test obj.last_file_bucket, obj.last_file_path
    end
  end

end; end; end