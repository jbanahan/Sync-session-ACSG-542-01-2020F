# == Schema Information
#
# Table name: business_validation_rules
#
#  id                              :integer          not null, primary key
#  business_validation_template_id :integer
#  type                            :string(255)
#  name                            :string(255)
#  description                     :string(255)
#  fail_state                      :string(255)
#  rule_attributes_json            :text
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  group_id                        :integer
#  delete_pending                  :boolean
#  notification_type               :string(255)
#  notification_recipients         :text
#  disabled                        :boolean
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

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

    @types.each do |t|
      if !object_attachment_types.include?(t.downcase)
        return "Missing attachment type #{t}."
      end
    end

    return nil

  end

end
