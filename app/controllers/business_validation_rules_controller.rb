require 'open_chain/email_validation_support'

class BusinessValidationRulesController < ApplicationController
  include OpenChain::EmailValidationSupport

  def create
    admin_secure do
      @bvr = BusinessValidationRule.new(params[:business_validation_rule])
      @bvt = BusinessValidationTemplate.find(params[:business_validation_template_id])
      @bvr.business_validation_template = @bvt # this will be unnecessary if b_v_t goes in attr_accessible

      unless valid_json(params[:business_validation_rule][:rule_attributes_json])
        error_redirect "Could not save due to invalid JSON. For reference, your attempted JSON was: #{params[:business_validation_rule][:rule_attributes_json]}"
        return
      end
        
      emails = params[:business_validation_rule][:notification_recipients]
      if emails.present? && !email_list_valid?(params[:business_validation_rule][:notification_recipients])        
        error_redirect "Could not save due to invalid email."
        return
      end

      if @bvr.save!
        redirect_to edit_business_validation_template_path(@bvt)
      else
        error_redirect "The rule could not be created."
      end
    end
  end

  def valid_json json
   begin
      JSON.parse(json) unless json.blank?
      true
    rescue
      false
    end
  end

  def edit #used for adding a criterion to a rule
    @no_action_bar = true
    admin_secure{
      @new_criterion = SearchCriterion.new
      @bvr = BusinessValidationRule.find(params[:id])
    }
  end

  def update
    admin_secure{
      @bvr = BusinessValidationRule.find(params[:id])
      @bvr.search_criterions = []
      unless valid_json(params[:business_validation_rule][:rule_attributes_json])
        render json: {error: "Could not save due to invalid JSON."}, status: 500
        return
      end

      emails = params[:business_validation_rule][:notification_recipients]
      if emails.present? && !email_list_valid?(params[:business_validation_rule][:notification_recipients])        
        render json: {error: "Could not save due to invalid email."}, status: 500
        return
      end
      
      if params[:business_validation_rule][:search_criterions].present?
        params[:business_validation_rule][:search_criterions].each { |search_criterion| add_search_criterion_to_rule(@bvr, search_criterion) }
      end
      params[:business_validation_rule].delete("search_criterions")
      @bvr.update_attributes!(params[:business_validation_rule].except("id", "mailing_lists", "business_validation_template_id", "search_criterions"))
      render json: {notice: "Business rule updated"}
    }
  end

  def destroy
    admin_secure do
      @bvr = BusinessValidationRule.find(params[:id])
      @bvt = @bvr.business_validation_template
      @bvr.update_attribute(:delete_pending, true)
      @bvr.destroy
      redirect_to edit_business_validation_template_path(@bvt)
    end
  end

  def edit_angular
    admin_secure do

      model_fields_list = make_model_fields_hashes
      business_rule_hash = make_business_rule_hash

      render json: {model_fields: model_fields_list, business_validation_rule: business_rule_hash[:business_validation_rule]}
    end
  end

  private

  def add_search_criterion_to_rule(rule, criterion)
    criterion["model_field_uid"] = criterion.delete("mfid")
    criterion.delete("datatype")
    criterion.delete("label")
    sc = SearchCriterion.new(criterion)
    rule.search_criterions << sc
    rule.save!
  end

  def make_business_rule_hash
    br = BusinessValidationRule.find(params[:id])
    # Hand created to avoid extraneous attributes and including the concrete validation rule's subclass name as the root
    # attribute name instead of 'business_validation_rule'
    br_json = {business_validation_rule:
      {
        mailing_lists: MailingList.mailing_lists_for_user(current_user).collect { |ml| {id: ml.id, label: ml.name} },
        business_validation_template_id: br.business_validation_template_id,
        mailing_list_id: br.mailing_list_id,
        description: br.description,
        fail_state: br.fail_state,
        id: br.id,
        name: br.name,
        disabled: br.disabled,
        rule_attributes_json: br.rule_attributes_json,
        type: br.type,
        group_id: br.group_id,
        notification_type: br.notification_type,
        notification_recipients: br.notification_recipients,
        suppress_pass_notice: br.suppress_pass_notice,
        suppress_review_fail_notice: br.suppress_review_fail_notice,
        suppress_skipped_notice: br.suppress_skipped_notice,
        subject_pass: br.subject_pass,
        subject_review_fail: br.subject_review_fail,
        subject_skipped: br.subject_skipped,
        message_pass: br.message_pass,
        message_review_fail: br.message_review_fail,
        message_skipped: br.message_skipped
      }
    }

    br_json[:business_validation_rule][:search_criterions] = br.search_criterions.collect {|sc| sc.json current_user}
    br_json
  end

  def make_model_fields_hashes
    cm = CoreModule.find_by_class_name(BusinessValidationRule.find(params[:id]).business_validation_template.module_type, true)
    @model_fields = cm.default_module_chain.model_fields(current_user).values
    model_fields_list = []
    @model_fields.each do |model_field|
      model_fields_list << {
          :field_name => model_field.field_name.to_s, :mfid => model_field.uid.to_s,
          :label => model_field.label, :datatype => model_field.data_type.to_s
          }
    end
    model_fields_list.sort { |a,b| a[:label].downcase <=> b[:label].downcase }
  end

end
