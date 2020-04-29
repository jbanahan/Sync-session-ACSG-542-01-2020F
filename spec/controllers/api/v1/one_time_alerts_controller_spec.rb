describe Api::V1::OneTimeAlertsController do
  let(:user) { Factory(:user) }
  let(:mailing_list) { Factory(:mailing_list, company: user.company, email_addresses: "tufnel@stonehenge.biz") }
  let!(:alert) { Factory(:one_time_alert, mailing_list: mailing_list, name: "OTA name", module_type: "Product") }

  before do
    allow_api_user user
    use_json
  end

  describe "edit" do
    before do
      DataCrossReference.create! cross_reference_type: 'ota_reference_fields', key: "Product~prod_attachment_count"
      DataCrossReference.create! cross_reference_type: 'ota_reference_fields', key: "Product~prod_attachment_types"
      DataCrossReference.create! cross_reference_type: 'ota_reference_fields', key: "Entry~ent_entry_number"
    end

    it "renders alert JSON for permitted user" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true
      mf_collection = [{:mfid=>:prod_attachment_count, :label=>"Attachment Count", :datatype=>:integer},
                       {:mfid=>:prod_attachment_types, :label=>"Attachment Types", :datatype=>:string}]
      alert = OneTimeAlert.first
      alert.search_criterions << Factory(:search_criterion)
      get :edit, id: alert.id
      expect(response.body).to eq({alert: alert, mailing_lists: [{"id" => nil, "label" => ""}, {"id" => mailing_list.id, "label" => mailing_list.name }], criteria: alert.search_criterions.map { |sc| sc.json(user) }, model_fields: mf_collection}.to_json)
    end

    it "prevents access by other users" do
      allow_api_access Factory(:user)
      get :edit, id: alert.id
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe "update" do
    let(:alert_new_criteria) { [{"mfid"=>"prod_uid", "label"=>"Unique Identifier", "operator"=>"eq", "value"=>"x", "datatype"=>"string", "include_empty"=>false}] }
    let(:time1) { DateTime.new 2018, 3, 15 }
    let(:time2) { DateTime.new 2018, 3, 16 }
    let(:time3) { DateTime.new 2018, 3, 17 }
    let(:time4) { DateTime.new 2018, 3, 18 }
    let(:user2) { Factory(:user) }

    before do
      alert.update_attributes(module_type: "original module_type", blind_copy_me: false, expire_date: time1, email_addresses: "tufnel@stonehenge.biz",
                               email_body: "original body", email_subject: "original subject", enabled_date: time2, mailing_list: nil,
                               name: "original name", user_id: user2.id)
      alert.search_criterions << Factory(:search_criterion, model_field_uid: "ent_brok_ref", "operator"=>"eq", "value"=>"w", "include_empty"=>true)
    end

    it "replaces basic fields and search criterions for a permitted user, leaves module_type unchanged" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time3, email_addresses: "sthubbins@hellhole.co.uk",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4,
                                          name: "new name", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria
      alert.reload
      criteria = alert.search_criterions
      new_criterion = (criteria.first.json user).to_json

      expect(alert.module_type).to eq "original module_type"
      expect(alert.user).to eq user2
      expect(alert.expire_date_last_updated_by).to eq user
      expect(alert.blind_copy_me).to eq true
      expect(alert.expire_date).to eq time3
      expect(alert.email_addresses).to eq "sthubbins@hellhole.co.uk"
      expect(alert.email_body).to eq "new body"
      expect(alert.email_subject).to eq "new subject"
      expect(alert.enabled_date).to eq time4
      expect(alert.name).to eq "new name"
      expect(ActionMailer::Base.deliveries.count).to eq 0

      expect(criteria.count).to eq 1
      expect(new_criterion).to eq (alert_new_criteria.first).to_json
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    it "doesn't update expire_date_last_updated_by if expire_date doesn't change" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true
      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time1, email_addresses: "sthubbins@hellhole.co.uk",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4,
                                          name: "new name", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria

      alert.reload
      expect(alert.expire_date_last_updated_by).to be_nil
    end

    it "errors if no email or mailing list found" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time3, email_addresses: "",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4,
                                          name: "new name", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria

      expect(JSON.parse(response.body)["error"]).to eq "Could not save due to missing or invalid email."
      alert.reload
      expect(alert.email_body).to eq "original body"
    end

    it "succeeds if only mailing list found (but not email)" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time3, email_addresses: "",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4, mailing_list_id: mailing_list.id,
                                          name: "new name", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria

      expect(JSON.parse(response.body)["ok"]).to eq "ok"
      alert.reload
      expect(alert.email_body).to eq "new body"
    end

    it "errors if email is invalid" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time3, email_addresses: "abc.com",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4,
                                          name: "new name", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria

      expect(JSON.parse(response.body)["error"]).to eq "Could not save due to missing or invalid email."
      alert.reload
      expect(alert.email_body).to eq "original body"
    end

    it "errors if name is left blank" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time3, email_addresses: "abc@abc.com",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4,
                                          name: "", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria

      expect(JSON.parse(response.body)["error"]).to eq "You must include a name."
      alert.reload
      expect(alert.email_body).to eq "original body"
    end

    it "blocks other users" do
      put :update, id: alert.id, alert: {module_type: "new module_type", blind_copy_me: true, expire_date: time3, email_addresses: "sthubbins@hellhole.co.uk",
                                          email_body: "new body", email_subject: "new subject", enabled_date: time4,
                                          name: "new name", user_id: Factory(:user).id},
                                  criteria: alert_new_criteria
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
      alert.reload
      expect(alert.blind_copy_me).to eq false
    end

    it "sends test email, if specified" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      alert.update_attributes! module_type: "Product"
      put :update, id: alert.id, alert: { name: "new name", email_addresses: "sthubbins@hellhole.co.uk"}, send_test: true
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  describe "destroy" do
    it "deletes alert for permitted user" do
      expect_any_instance_of(OneTimeAlert).to receive(:can_edit?).with(user).and_return true

      expect { delete :destroy, id: alert.id }.to change(OneTimeAlert, :count).from(1).to 0
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    it "prevents access by anyone else" do
      expect { delete :destroy, id: alert.id }.to_not change(OneTimeAlert, :count)
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe "update_reference_fields" do
    let!(:xref1) { DataCrossReference.create!(cross_reference_type: "ota_reference_fields", key: "Entry~ent_entry_num" ) }
    let!(:xref2) { DataCrossReference.create!(cross_reference_type: "ota_reference_fields", key: "Product~prod_uid" ) }

    before { use_json }

    it "allows changes by admin users" do
      allow_api_user Factory(:admin_user)
      post :update_reference_fields, fields: { "Entry" => [{"mfid" => "ent_entry_num", "label" => "Entry Number"},
                                                           {"mfid" => "ent_release_date", "label" => "Release Date"}],
                                               "Product" => [{"mfid" => "prod_ent_type", "label" => "Product Type"}] }

      expect(JSON.parse(response.body)["ok"]).to eq "ok"

      fields = DataCrossReference.where(cross_reference_type: "ota_reference_fields").pluck(:key).sort
      expect(fields).to eq ["Entry~ent_entry_num", "Entry~ent_release_date", "Product~prod_ent_type"]
    end

    it "rejects non-admin users" do
      post :update_reference_fields, fields: { "Entry" => [{"mfid" => "ent_entry_num", "label" => "Entry Number"}],
                                               "Product" => [{"mfid" => "prod_ent_type", "label" => "Product Type"}] }

      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})

      fields = DataCrossReference.where(cross_reference_type: "ota_reference_fields").pluck(:key).sort
      expect(fields).to eq ["Entry~ent_entry_num", "Product~prod_uid"]
    end
  end
end
