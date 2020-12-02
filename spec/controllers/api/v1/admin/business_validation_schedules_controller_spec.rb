describe Api::V1::Admin::BusinessValidationSchedulesController do
  let! :user do
    u = create(:admin_user)
    allow_api_user u
    u
  end

  before {use_json}

  describe "new" do
    it "renders list of modules for admin, excluding any disabled ones" do
      expect(CoreModule::ENTRY).to receive(:enabled_lambda).and_return(-> { true })
      expect(CoreModule::ORDER).to receive(:enabled_lambda).and_return(-> { true })
      expect(CoreModule::PRODUCT).to receive(:enabled_lambda).and_return(-> { false })
      get :new
      expect(JSON.parse(response.body)).to eq({"cm_list" => ["Entry", "Order"]})
    end

    it "prevents access by non-admins" do
      allow_api_access create(:user)
      get :new
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "index" do
    it "renders list of schedules for admin" do
      sched1 = create(:business_validation_schedule, name: "name 1", module_type: "Entry", model_field_uid: "ent_release_date", operator: "Before", num_days: 1)
      sched2 = create(:business_validation_schedule, name: "name 2", module_type: "Product", model_field_uid: "prod_created_at", operator: "After", num_days: 5)
      get :index
      expect(JSON.parse(response.body)).to eq([{"id" => sched1.id, "name" => "name 1", "module_type" => "Entry", "date" => "1 day Before Release Date"},
                                               {"id" => sched2.id, "name" => "name 2", "module_type" => "Product", "date" => "5 days After Created Time"}])
    end

    it "prevents access by non-admins" do
      allow_api_access create(:user)
      get :index
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "edit" do
    it "renders schedule JSON for admin" do
      criterion_mfs = {criterion_mfs: []}

      schedule = create(:business_validation_schedule, module_type: "Entry")
      schedule.search_criterions << create(:search_criterion)

      expect_any_instance_of(described_class).to receive(:criterion_mf_hsh).with(CoreModule::ENTRY, schedule).and_return criterion_mfs
      expect_any_instance_of(described_class).to receive(:schedule_mf_hsh).with(CoreModule::ENTRY, user).and_return schedule
      get :edit, id: schedule.id
      expect(response.body).to eq({schedule: schedule,
                                   criteria: schedule.search_criterions.map { |sc| sc.json(user) },
                                   criterion_model_fields: criterion_mfs,
                                   schedule_model_fields: schedule}.to_json)
    end

    it "prevents access by non-admins" do
      allow_api_access create(:user)
      get :edit, id: 1
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "create" do
    it "creates schedule for admin" do
      expect { post :create, schedule: {name: "sched name", module_type: "Entry"} }.to change(BusinessValidationSchedule, :count).from(0).to 1
      sched = BusinessValidationSchedule.first
      expect(JSON.parse(response.body)["id"]).to eq sched.id
      expect(sched.name).to eq "sched name"
      expect(sched.module_type).to eq "Entry"
    end

    it "errors if name is missing" do
      expect { post :create, schedule: {name: "", module_type: "Entry"} }.not_to change(BusinessValidationSchedule, :count)
      expect(JSON.parse(response.body)["errors"]).to eq ["Name cannot be blank."]
    end

    it "errors if module type is missing" do
      expect { post :create, schedule: {name: "sched name", module_type: ""} }.not_to change(BusinessValidationSchedule, :count)
      expect(JSON.parse(response.body)["errors"]).to eq ["Module Type cannot be blank."]
    end

    it "prevents access by non-admins" do
      allow_api_access create(:user)
      expect {post :create, schedule: {name: "sched name", module_type: "Entry"} }.not_to change(BusinessValidationSchedule, :count)
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "update" do
    let!(:schedule) do
      sch = create(:business_validation_schedule)
      sch.update(module_type: "original module_type", model_field_uid: "original mf uid", name: "original name", operator: "original operator", num_days: 1)
      sch.search_criterions << create(:search_criterion, model_field_uid: "ent_brok_ref", "operator" => "eq", "value" => "w", "include_empty" => true)
      sch
    end

    let!(:schedule_new_criteria) do
      [{"mfid" => "prod_uid", "label" => "Unique Identifier", "operator" => "eq", "value" => "x", "datatype" => "string", "include_empty" => false}]
    end

    it "replaces basic fields and search criterions for a sys-admin, leaves module_type unchanged" do
      put :update, id: schedule.id, schedule: {module_type: "new module_type", model_field_uid: "new mf uid",
                                               name: "new name", operator: "new operator", num_days: 10},
                   criteria: schedule_new_criteria
      schedule.reload
      criteria = schedule.search_criterions
      new_criterion = (criteria.first.json user).to_json

      expect(schedule.module_type).to eq "original module_type"
      expect(schedule.model_field_uid).to eq "new mf uid"
      expect(schedule.name).to eq "new name"
      expect(schedule.operator).to eq "new operator"
      expect(schedule.num_days).to eq 10
      expect(criteria.count).to eq 1
      expect(new_criterion).to eq schedule_new_criteria.first.to_json
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    it "errors if search criterions are missing" do
      put :update, id: schedule.id, schedule: {model_field_uid: "new mf uid", name: "new name", operator: "new operator", num_days: 10}, criteria: []
      schedule.reload
      expect(schedule.search_criterions.count).to eq 1
      expect(JSON.parse(response.body)["errors"]).to eq ["Schedule must include search criterions."]
    end

    it "errors if name is missing" do
      put :update, id: schedule.id, schedule: {model_field_uid: "new mf uid", name: "", operator: "new operator", num_days: 10}, criteria: schedule_new_criteria
      schedule.reload
      expect(schedule.name).to eq "original name"
      expect(JSON.parse(response.body)["errors"]).to eq ["Name cannot be blank."]
    end

    it "errors if date is not complete" do
      put :update, id: schedule.id, schedule: {model_field_uid: "", name: "new name", operator: "new operator", num_days: 10}, criteria: schedule_new_criteria
      schedule.reload
      expect(schedule.model_field_uid).to eq "original mf uid"
      expect(JSON.parse(response.body)["errors"]).to eq ["Date must be complete."]

      put :update, id: schedule.id, schedule: {model_field_uid: "new mf uid", name: "new name", operator: "", num_days: 10}, criteria: schedule_new_criteria
      schedule.reload
      expect(schedule.operator).to eq "original operator"
      expect(JSON.parse(response.body)["errors"]).to eq ["Date must be complete."]

      put :update, id: schedule.id, schedule: {model_field_uid: "new mf uid", name: "new name", operator: "new operator", num_days: nil}, criteria: schedule_new_criteria
      schedule.reload
      expect(schedule.num_days).to eq 1
      expect(JSON.parse(response.body)["errors"]).to eq ["Date must be complete."]
    end

    it "prevents access by non-admins" do
      allow_api_access create(:user)
      put :update, id: schedule.id, criteria: schedule_new_criteria
      schedule.reload
      criteria = schedule.search_criterions

      expect(schedule.model_field_uid).to eq "original mf uid"
      expect(schedule.name).to eq "original name"
      expect(schedule.operator).to eq "original operator"
      expect(schedule.num_days).to eq 1
      expect(criteria.count).to eq 1
      expect(criteria.first.model_field_uid).to eq "ent_brok_ref"
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "destroy" do
    let!(:schedule) { create(:business_validation_schedule) }

    it "destroys schedule for admin" do
      expect { delete :destroy, id: schedule.id }.to change(BusinessValidationSchedule, :count).from(1).to 0
      expect(JSON.parse(response.body)['ok']).to eq 'ok'
    end

    it "prevents access by non-admins" do
      allow_api_access create(:user)
      expect { delete :destroy, id: schedule.id }.not_to change(BusinessValidationSchedule, :count)
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "criterion_mf_hsh" do
    it "takes the model fields associated with a schedule's module returns only the mfid, label, and datatype fields" do
      schedule = create(:business_validation_schedule, module_type: "Product")
      mfs = described_class.new.criterion_mf_hsh CoreModule::PRODUCT, schedule
      expect(mfs.find {|mf| mf[:mfid] == :prod_uid}).to eq({mfid: :prod_uid, label: "Unique Identifier", datatype: :string })
    end
  end

  describe "schedule_mf_hsh" do
    it "returns model-field id/label pairs for core module" do
      mf1 = ModelField.by_uid "ent_entry_num"
      mf2 = ModelField.by_uid "ent_filed_date"
      mf3 = ModelField.by_uid "ent_duty_due_date"
      mfs = {mf1.uid => mf1, mf2.uid => mf2, mf3.uid => mf3}
      expect(CoreModule::ENTRY).to receive(:model_fields).with(user).and_return mfs
      expect(described_class.new.schedule_mf_hsh(CoreModule::ENTRY, user)).to eq([{'mfid' => 'ent_duty_due_date', 'label' => 'Duty Due Date'},
                                                                                  {'mfid' => 'ent_filed_date', 'label' => 'Entry Filed Date'}])
    end
  end
end
