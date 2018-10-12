# == Schema Information
#
# Table name: business_validation_rules
#
#  business_validation_template_id :integer
#  created_at                      :datetime         not null
#  delete_pending                  :boolean
#  description                     :string(255)
#  disabled                        :boolean
#  fail_state                      :string(255)
#  group_id                        :integer
#  id                              :integer          not null, primary key
#  mailing_list_id                 :integer
#  message_pass                    :string(255)
#  message_review_fail             :string(255)
#  message_skipped                 :string(255)
#  name                            :string(255)
#  notification_recipients         :text
#  notification_type               :string(255)
#  rule_attributes_json            :text
#  subject_pass                    :string(255)
#  subject_review_fail             :string(255)
#  subject_skipped                 :string(255)
#  suppress_pass_notice            :boolean
#  suppress_review_fail_notice     :boolean
#  suppress_skipped_notice         :boolean
#  type                            :string(255)
#  updated_at                      :datetime         not null
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
