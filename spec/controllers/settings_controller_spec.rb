require 'spec_helper'

describe SettingsController do
  describe "summary" do
    let!(:user) { Factory(:admin_user) }
    before { sign_in_as user }
      
    it "renders and assigns data" do
      ord_cm = CoreModule::ORDER
      mf = ModelField.find_by_uid(:ord_closed_by)
      
      allow(CoreModule).to receive(:all).and_return([ord_cm])
      expect(ord_cm).to receive(:model_fields).and_return({ord_closed_by: mf})

      cdef = Factory(:custom_definition, module_type: "Order", data_type: "string", label: "Custom Field Label")
      stb = Factory(:state_toggle_button, module_type: "Order")
      stc = Factory(:search_table_config)
      group = Factory(:group)
      non_import_country = Factory(:country, import_location: false)
      import_country = Factory(:country, import_location: true)
      bvt = Factory(:business_validation_template)
      att_type = AttachmentType.create!
      sched_job = Factory(:schedulable_job, run_class: "OpenChain::SomeReport")

      get :system_summary
      expect(response).to be_success
      expect(assigns(:collections)).to eq({ model_field: {"Order" => [mf]}, 
                                            custom_definition: {"Order" => [cdef]}, 
                                            state_toggle_button: {"Order" => [stb]}, 
                                            group: [group], 
                                            search_table_config: [stc], 
                                            import_country: [import_country],
                                            business_validation_template: [bvt],
                                            attachment_type: [att_type],
                                            schedulable_job: [sched_job] }.with_indifferent_access)
    end
    
    it "only allows use by admins" do
      user.admin = false; user.save!
      get :system_summary
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only administrators can view the system summary."]
    end
  end   
end