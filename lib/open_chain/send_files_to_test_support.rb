module OpenChain; module SendFilesToTestSupport

  def self.included base
    # Yields objects that can be sent to test while handling the error/notification flash and redirect.
    # The caller does the actual send.
    base.class_eval do
      def send_to_test_redirect entity, integration_files: false
        msg_handler = MessageHandler.new(integration_files)
        Array.wrap(entity).each { |ent| yield ent if msg_handler.can_send?(ent, current_user) }
        msg_handler.messages.each { |msg| add_flash((msg_handler.errors? ? :errors : :notices), msg) }
        redirect_back_or_default :back
      end
    end
  end

  class MessageHandler
    attr_accessor :errors, :entity_count, :integration

    def initialize integration_files = false
      @integration = integration_files
      @entity_count = 0
      @errors = Hash.new do |h, k|
        h[k] = Hash.new { |h2, k2| h2[k2] = [] }
      end
    end

    def can_send? obj, current_user
      self.entity_count += 1
      if obj&.can_view?(current_user)
        if obj.class.respond_to?(:send_integration_file_to_test)
          return true if obj_has_integration_file? obj
        elsif obj.respond_to? :s3_path
          return true if obj_has_standard_file? obj
        else
          errors[:invalid_obj][obj.class.name.titleize] << obj.id
        end
      else
        errors[:permission][obj.class.name.titleize] << obj&.id
      end

      false
    end

    def messages
      if !errors?
        meth = entity_count != 1 ? :pluralize : :singularize
        [%(#{file_type.capitalize.public_send(meth)} #{"has".public_send(meth)} been queued to be sent to test.)]
      else
        msg = ["One or more #{file_type.pluralize} cannot be sent to test."]
        errors[:missing_file].each do |klass, ids|
          meth = ids.count != 1 ? :pluralize : :singularize
          msg << "The following #{klass.public_send(meth)} could not be found and may have been purged: ID #{ids.join(", ")}"
        end
        errors[:missing_path].each do |klass, ids|
          meth = ids.count != 1 ? :pluralize : :singularize
          msg << "The following #{klass.public_send(meth)} #{"is".public_send(meth)} missing a #{file_type} path: ID #{ids.join(", ")}"
        end
        errors[:missing_bucket].each do |klass, ids|
          meth = ids.count != 1 ? :pluralize : :singularize
          msg << "The following #{klass.public_send(meth)} #{"is".public_send(meth)} missing a #{file_type} bucket: ID #{ids.join(", ")}"
        end
        errors[:invalid_obj].each do |klass, ids|
          msg << "#{klass} is an invalid type: ID #{ids.join(", ")}"
        end
        errors[:permission].each do |klass, ids|
          meth = ids.count != 1 ? :pluralize : :singularize
          msg << "You do not have permission to send the following #{klass.public_send(meth)} to test: ID #{ids.compact.join(", ")}"
        end
        msg << "The remaining #{file_type.pluralize} have been sent." if entity_count > error_count
        msg
      end
    end

    def errors?
      error_count.positive?
    end

    private

    def file_type
      integration ? "integration file" : "file"
    end

    def error_count
      errors.values.map(&:values).flatten.count
    end

    def obj_has_integration_file? obj
      if obj&.has_last_file?
        # Verify the last_file_bucket / last_file_path still exists in S3.  Files are expunged from S3 after 2 years, so
        # old files may not exist any longer.  If this happens report an error to the user.
        if OpenChain::S3.exists? obj.last_file_bucket, obj.last_file_path
          return true
        else
          errors[:missing_file][obj.class.name.titleize] << obj.id
        end
      end

      false
    end

    def obj_has_standard_file? obj
      if obj.s3_bucket && obj.s3_path
        if OpenChain::S3.exists? obj.s3_bucket, obj.s3_path
          return true
        else
          errors[:missing_file][obj.class.name.titleize] << obj.id
        end
      else
        errors[:missing_path][obj.class.name.titleize] << obj.id unless obj.s3_path
        errors[:missing_bucket][obj.class.name.titleize] << obj.id unless obj.s3_bucket
      end

      false
    end

  end

end; end
