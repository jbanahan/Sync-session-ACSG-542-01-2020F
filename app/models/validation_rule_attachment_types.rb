class ValidationRuleAttachmentTypes < BusinessValidationRule

  def run_validation obj
    validate_attachment_types obj
  end

  def validate_attachment_types obj
    #returns nil (passing) or the first required attachment type which was not found
    @attrs ||= self.rule_attributes
    @types = @attrs['attachment_types']

    return nil if @types.blank?

    @types = [@types] if @types.instance_of?(String)
    object_attachment_types = obj.attachments.collect {|a| a.attachment_type.downcase}

    @types.each do |t|
      if !object_attachment_types.include?(t.downcase)
        raise "Missing attachment type #{t}."
      end
    end

    return nil

  end

end