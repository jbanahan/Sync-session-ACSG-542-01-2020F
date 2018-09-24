# == Schema Information
#
# Table name: inbound_files
#
#  company_id                  :integer
#  created_at                  :datetime         not null
#  file_name                   :string(255)
#  id                          :integer          not null, primary key
#  isa_number                  :string(255)
#  original_process_start_date :datetime
#  parser_name                 :string(255)
#  process_end_date            :datetime
#  process_start_date          :datetime
#  process_status              :string(255)
#  receipt_location            :string(255)
#  requeue_count               :integer
#  s3_bucket                   :string(255)
#  s3_path                     :string(255)
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_inbound_files_on_s3_bucket_and_s3_path  (s3_bucket,s3_path)
#

class InboundFile < ActiveRecord::Base
  has_many :identifiers, dependent: :destroy, class_name: 'InboundFileIdentifier', autosave: true, inverse_of: :inbound_file
  has_many :messages, dependent: :destroy, class_name: 'InboundFileMessage', autosave: true, inverse_of: :inbound_file
  belongs_to :company

  PROCESS_STATUS_PENDING = "Pending"
  PROCESS_STATUS_SUCCESS = "Success"
  PROCESS_STATUS_WARNING = "Warning"
  PROCESS_STATUS_REJECT = "Rejected"
  PROCESS_STATUS_ERROR = "Error"

  def self.find_can_view(user)
    if user.sys_admin?
      return InboundFile.where("1=1")
    end
  end

  def can_view? user
    user.sys_admin?
  end

  def get_process_status_from_messages
    overall_status = 1
    messages.each do |msg|
      case msg.message_status
        when InboundFileMessage::MESSAGE_STATUS_WARNING
          overall_status = [2, overall_status].max
        when InboundFileMessage::MESSAGE_STATUS_REJECT
          overall_status = [3, overall_status].max
        when InboundFileMessage::MESSAGE_STATUS_ERROR
          overall_status = 4
      end
    end

    case overall_status
      when 1
        process_status = PROCESS_STATUS_SUCCESS
      when 2
        process_status = PROCESS_STATUS_WARNING
      when 3
        process_status = PROCESS_STATUS_REJECT
      when 4
        process_status = PROCESS_STATUS_ERROR
    end
    process_status
  end

  def add_info_message message
    add_message InboundFileMessage::MESSAGE_STATUS_INFO, message
  end

  def add_warning_message message
    add_message InboundFileMessage::MESSAGE_STATUS_WARNING, message
  end

  # Business rule-type failure: missing info, etc.
  def add_reject_message message
    add_message InboundFileMessage::MESSAGE_STATUS_REJECT, message
  end

  # Convenience method to add a rejection message to the log, then raise an exception (LoggedParserRejectionError) with
  # that same message.  error_class, if provided, should, ideally, extend UnreportedError or LoggedParserRejectionError,
  # unless the error is handled internally within the parser.  If error_class extends one of those classes, or if no
  # error_class is provided, the error will not be double-logged or re-rethrown.
  def reject_and_raise message, error_class:nil
    add_reject_message message
    raise_error error_class ? error_class : LoggedParserRejectionError, message
  end

  # Unanticipated exception.
  def add_error_message message
    add_message InboundFileMessage::MESSAGE_STATUS_ERROR, message
  end

  # Convenience method to add an error message to the log, then raise an exception (RuntimeError) with that same message.
  # Errors of this type typically represent mistakes of ours (e.g. supporting data we forgot to set up, code bugs)
  # rather than goofs in the data being parsed.  error_class, if provided, should, ideally, extend
  # LoggedParserFatalError, unless the error is handled internally within the parser.  If error_class extends that
  # class, or if no error_class is provided, the error will not be double-logged in IntegrationClientParser.  It will
  # still be re-thrown by IntegrationClientParser, regardless.
  def error_and_raise message, error_class:nil
    add_error_message message
    raise_error error_class ? error_class : LoggedParserFatalError, message
  end

  # Throws an exception if message_status is not one of the types defined in InboundFileMessage.
  def add_message message_status, message
    if !InboundFileMessage::MESSAGE_STATUSES.include?(message_status)
      raise ArgumentError.new("Invalid message status: #{message_status}")
    end
    messages.build(message_status:message_status, message:message)
    nil
  end

  # This method assumes these messages have not yet been saved.  Saved messages deemed to be dupes will be removed
  # from the InboundFile object, but won't actually be deleted from the database.  Be careful of where you use it.
  # Only unique combinations of status and message are retained. The original order of the messages is still
  # maintained, however.
  def remove_dupe_messages
    messages.replace messages.to_a.uniq { |msg| (msg.message_status + "_" + msg.message) }
    nil
  end

  # Returns the messages matching the provided status, or empty array if no match.
  def get_messages_by_status message_status
    messages.select { |msg| msg.message_status == message_status }
  end

  # Throws an exception if module_type is not nil and the value is not one of the CoreModules.
  def add_identifier identifier_type, value, module_type:nil, module_id:nil
    validate_identifier_module_type module_type
    # Prevents a dupe from being added.
    if get_identifiers(identifier_type, value:value).length == 0
      identifiers.build(identifier_type:identifier_type, value:value, module_type:module_type, module_id:module_id)
    end
    nil
  end

  # Sets module info against all identifiers of a specific type that have already been added to the identifiers array,
  # allowing identifiers to be set before module ID is set (something that is often useful for parsing, if there's a
  # chance the module look-up could fail).  Does not save these changes.  Throws an exception if module_type is not
  # nil and the value is not one of the CoreModules.  Doesn't do anything if an identifier of the provided type has
  # not been previously added to the identifiers array.  If identifier value is specified, sets only the identifier that
  # matches specifically by both type and value.
  def set_identifier_module_info identifier_type, module_type, module_id, value:nil
    validate_identifier_module_type module_type
    get_identifiers(identifier_type, value:value).each do |ident|
      ident.module_type = module_type
      ident.module_id = module_id
    end
    nil
  end

  # Returns the identifiers matching the provided type, or empty array if no match.  Value can be provided optionally
  # to further restrict the results returned to just one specific identifier (hopefully).
  def get_identifiers identifier_type, value:nil
    identifiers.select { |id| id.identifier_type == identifier_type && (!value || id.value == value) }
  end

  def self.purge reference_date
    InboundFile.where("created_at < ?", reference_date).find_each do |inf|
      inf.destroy
    end
  end

  private
    def validate_identifier_module_type module_type
      if module_type && !CoreModule.find_by_class_name(module_type)
        raise ArgumentError.new("Invalid module type: #{module_type}")
      end
    end

    def raise_error error_class, message
      if error_class.nil?
        raise message
      else
        raise error_class, message
      end
    end

end
