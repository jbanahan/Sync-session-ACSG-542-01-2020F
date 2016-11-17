class SettingsController < ApplicationController
  
  def index
    admin_secure("Only administrators can adjust system settings.") { 
      render layout:false 
    }    
  end
  
  def tools
    render :layout=>'one_col'
  end

  def setup
  end

  def system_summary
    admin_secure("Only administrators can view the system summary.") {
      @collections = { model_field: {}, custom_definition: {}, state_toggle_button: {} }
      CoreModule.all.sort_by(&:label).each do |cm|
        @collections[:model_field][cm.label] = []
        cm.model_fields.reject{|k,v| v.custom?}
                       .sort_by{|k,v| v.label}
                       .each{|mf_tup| @collections[:model_field][cm.label] << mf_tup[1]}
        @collections[:custom_definition][cm.label] = CustomDefinition.where(module_type: cm.class_name).order(:label)
        @collections[:state_toggle_button][cm.label] = StateToggleButton.where(module_type: cm.class_name)
      end
      @collections[:business_validation_template] = BusinessValidationTemplate.order(:name)
      @collections[:group] = Group.order(:name)
      @collections[:search_table_config] = SearchTableConfig.order(:name)
      @collections[:import_country] = Country.where(import_location: true).order(:name)
      @collections[:attachment_type] = AttachmentType.order(:name)
      @collections[:schedulable_job] = SchedulableJob.all.sort_by{|sj| sj.run_class.split("::").last}
      @collections
    }
  end
  
end
