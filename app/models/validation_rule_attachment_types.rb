# -*- SkipSchemaAnnotations

# Checks that entity has all specified attachment types
# {'attachment_types' : [string] | string}
class ValidationRuleAttachmentTypes < BusinessValidationRule

  def run_validation obj
    validate_attachment_types obj
  end

  def validate_attachment_types obj
    #returns nil (passing) or the first required attachment type which was not found
    @attrs ||= self.rule_attributes
    @types = @attrs['attachment_types']

    raise "No attachment types were specified." if @types.blank?

    @types = [@types] if @types.instance_of?(String)
    object_attachment_types = obj.attachments.collect {|a| a.attachment_type.downcase}

    missing = @types.select{ |t| !object_attachment_types.include?(t.downcase) }
    return "Missing attachment types: #{missing.join(', ')}." if missing.present?

    return nil
  end

end
