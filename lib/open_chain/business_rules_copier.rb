require 'open_chain/name_incrementer'

module OpenChain; module BusinessRulesCopier
  
  class Uploader
    def initialize custom_file
      @custom_file = custom_file
    end

    def process user, parameters
      begin
        OpenChain::S3.download_to_tempfile(@custom_file.bucket, @custom_file.path) do |file|
          template_hsh = JSON.parse(file.read)
          bvt = BusinessValidationTemplate.parse_copy_attributes(template_hsh)
          name = OpenChain::NameIncrementer.increment bvt.name, self.class.parent.template_names
          bvt.update_attributes! name: name, disabled: true
          user.messages.create subject: "File Processing Complete", body: "Business Validation Template upload for file #{@custom_file.attached_file_name} is complete."
        end
      rescue => e        
        user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
      end
    end
  end

  def self.copy_template user_id, template_id
    bvt = BusinessValidationTemplate.find template_id
    attributes = bvt.copy_attributes include_external: true
    create_template bvt.name, attributes
    user = User.find user_id
    user.messages.create subject: "Business Validation Template has been copied.", body: "Business Validation Template '#{bvt.name}' has been copied."
  end

  def self.copy_rule user_id, rule_id, template_id
    bvt = BusinessValidationTemplate.find template_id
    bvr = BusinessValidationRule.find rule_id
    attributes = bvr.copy_attributes include_external: true
    copied_rule = create_rule bvr.name, bvt.id, attributes
    bvt.business_validation_rules << copied_rule
    user = User.find user_id
    user.messages.create subject: "Business Validation Rule has been copied.", body: "Business Validation Rule '#{bvr.name}' has been copied."
  end

  private

  def self.create_template base_template_name, attributes
    name = OpenChain::NameIncrementer.increment base_template_name, template_names
    new_template = BusinessValidationTemplate.parse_copy_attributes(attributes)
    new_template.update_attributes! name: name, disabled: true
    new_template
  end

  def self.create_rule base_rule_name, template_id, attributes
    name = OpenChain::NameIncrementer.increment base_rule_name, rule_names(template_id)
    new_rule = BusinessValidationRule.parse_copy_attributes(attributes)
    new_rule.update_attributes! name: name, disabled: true
    new_rule
  end

  def self.template_names
    BusinessValidationTemplate.where(delete_pending: [nil, false]).map(&:name)
  end
  
  def self.rule_names template_id
    BusinessValidationRule.where(business_validation_template_id: template_id, delete_pending: [nil, false]).map(&:name)
  end

end; end
