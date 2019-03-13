require 'open_chain/business_rules_copier'

class BusinessValidationTemplatesController < ApplicationController

  def new
    admin_secure {
      @new_bvt = BusinessValidationTemplate.new
    }
  end

  def create
    admin_secure {
      @bvt = BusinessValidationTemplate.new(params[:business_validation_template])

      if @bvt.save
        redirect_to edit_business_validation_template_path(@bvt), notice: "Template successfully created."
      else
        render action: "new"
      end
    }
  end

  def edit
    admin_secure {
      @bvt = BusinessValidationTemplate.find(params[:id])
      @criteria = @bvt.search_criterions
      @rules = @bvt.business_validation_rules.reject(&:delete_pending)
      @new_criterion = SearchCriterion.new
      @new_rule = BusinessValidationRule.new
      @groups = Group.all
      @mailing_lists = MailingList.mailing_lists_for_user(current_user)
      @templates = BusinessValidationTemplate.where(delete_pending: [nil, false]).order(:name)
    }
  end

  def update
    admin_secure {
      @bvt = BusinessValidationTemplate.find(params[:id])

      if params[:search_criterions_only] == true
        @bvt.search_criterions = []
        params[:business_validation_template][:search_criterions].each do |search_criterion|
          add_search_criterion_to_template(@bvt, search_criterion)
        end unless params[:business_validation_template][:search_criterions].blank?
        render json: {ok: "ok"}

      else
        if @bvt.update_attributes(params[:business_validation_template])
          flash[:success] = "Template successfully saved."
          redirect_to @bvt
        else
          render 'edit'
        end

      end
    }
  end

  def index
    admin_secure {
      @bv_templates = BusinessValidationTemplate.all.reject(&:delete_pending)
    }
  end

  def show
    admin_secure {
      @bv_template = BusinessValidationTemplate.find params[:id]
    }
  end

  def destroy
    admin_secure{
      @bv_template = BusinessValidationTemplate.find params[:id]
      @bv_template.update_attribute(:delete_pending, true)
      @bv_template.business_validation_rules.update_all(delete_pending: true)
      BusinessValidationTemplate.delay.async_destroy @bv_template.id

      redirect_to business_validation_templates_path
    }
  end

  def download    
    admin_secure {
      bvt = BusinessValidationTemplate.find params[:id]
      json = bvt.copy_attributes.to_json
      filename = "#{bvt.name}_#{Date.today.strftime("%m-%d-%Y")}.json"
      send_data json, filename: filename, type: 'application/json', disposition: "attachment"
    }
  end

  def upload
    admin_secure {
      file = params[:attached]
      if file.nil?
        error_redirect "You must select a file to upload."
      else
        uploader = OpenChain::BusinessRulesCopier::TemplateUploader
        cf = CustomFile.create!(file_type: uploader.to_s, uploaded_by: current_user, attached: file)
        CustomFile.delay.process(cf.id, current_user.id)
        add_flash(:notices, "Your file is being processed. You'll receive a VFI Track message when it completes.")
        redirect_to business_validation_templates_path
      end
    }
  end

  def copy
    admin_secure {
      OpenChain::BusinessRulesCopier.delay.copy_template(current_user.id, params[:id].to_i)
      add_flash(:notices, "Business Validation Template is being copied. You'll receive a VFI Track message when it completes.")
      redirect_to business_validation_templates_path
    }
  end

  def manage_criteria
    @no_action_bar = true
    @bvt = BusinessValidationTemplate.find(params[:id])
  end

  def edit_angular
    admin_secure do
      model_fields_list = make_model_fields_hashes
      business_template_hash = make_business_template_hash

      render json: {model_fields: model_fields_list, business_template: business_template_hash}
    end
  end

  private

  def add_search_criterion_to_template(template, criterion)
    criterion["model_field_uid"] = criterion.delete("mfid")
    criterion.delete("datatype")
    criterion.delete("label")
    sc = SearchCriterion.new(criterion)
    template.search_criterions << sc
    template.save!
  end

  def make_business_template_hash
    bt = BusinessValidationTemplate.find(params[:id])

    bt_json = JSON.parse(bt.to_json)
    bt_json["business_validation_template"]["search_criterions"] = bt.search_criterions.collect {|sc| sc.json(current_user)}

    return bt_json
  end

  def make_model_fields_hashes
    cm = CoreModule.find_by_class_name(BusinessValidationTemplate.find(params[:id]).module_type, true)
    @model_fields = cm.default_module_chain.model_fields(current_user).values
    model_fields_list = []
    @model_fields.each do |model_field|
      model_fields_list << {
          :field_name => model_field.field_name.to_s, :mfid => model_field.uid.to_s,
          :label => model_field.label, :datatype => model_field.data_type.to_s
          }
    end
    return model_fields_list
  end

end
