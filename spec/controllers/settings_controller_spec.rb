describe SettingsController do
  describe "summary" do
    let!(:user) { Factory(:admin_user) }
    before { sign_in_as user }

    it "renders and assigns data" do
      shp_cm = CoreModule::SHIPMENT
      mf = ModelField.find_by_uid(:shp_ref)

      allow(CoreModule).to receive(:all).and_return([shp_cm])
      expect(shp_cm).to receive(:model_fields).and_return({shp_ref: mf})

      stb = Factory(:state_toggle_button, module_type: "Shipment", user_attribute: "shp_canceled_by", date_attribute: "shp_canceled_date")
      stc = Factory(:search_table_config)
      group = Factory(:group)
      non_import_country = Factory(:country, import_location: false)
      import_country = Factory(:country, import_location: true)
      bvt = Factory(:business_validation_template)
      att_type = AttachmentType.create!
      sched_job = Factory(:schedulable_job, run_class: "OpenChain::SomeReport")

      get :system_summary
      expect(response).to be_success
      expect(assigns(:collections)).to eq({ model_field: {"Shipment" => [mf]},
                                            state_toggle_button: {"Shipment" => [stb]},
                                            group: [group],
                                            search_table_config: [stc],
                                            import_country: [import_country],
                                            business_validation_template: [bvt],
                                            attachment_type: [att_type],
                                            schedulable_job: [sched_job] })
    end

    it "only allows use by admins" do
      user.admin = false; user.save!
      get :system_summary
      expect(response).to be_redirect
      expect(flash[:errors]).to eq ["Only administrators can view the system summary."]
    end
  end
end