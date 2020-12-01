describe Api::V1::Admin::StateToggleButtonsController do
  let!(:user) { FactoryBot(:admin_user) }

  before do
    allow_api_user user
    use_json
  end

  describe "edit" do
    let!(:stb) { FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by') }

    it "renders template JSON for a admin" do
      sc_mfs = [{mfid: :prod_attachment_count, label: "Attachment Count", datatype: :integer}]
      user_mfs = [{mfid: "ord_closed_by", label: "Closed By"}]
      date_mfs = [{mfid: "ord_closed_at", label: "Closed At"}]
      user_cdefs = [{cdef_id: 1, label: "QA Hold By"}]
      date_cdefs = [{cdef_id: 2, label: "QA Hold Date"}]
      stb.search_criterions << FactoryBot(:search_criterion)

      expect_any_instance_of(described_class).to receive(:get_sc_mfs).with(stb).and_return sc_mfs
      expect_any_instance_of(described_class).to receive(:get_user_and_date_mfs).with(stb).and_return [user_mfs, date_mfs]
      expect_any_instance_of(described_class).to receive(:get_user_and_date_cdefs).with(stb).and_return [user_cdefs, date_cdefs]

      get :edit, id: stb.id, format: "json"
      output = {button: stb,
                criteria: stb.search_criterions.map { |sc| sc.json(user) },
                sc_mfs: sc_mfs,
                user_mfs: user_mfs,
                user_cdefs: user_cdefs,
                date_mfs: date_mfs,
                date_cdefs: date_cdefs}
      expect(response.body).to eq(output.to_json)
    end

    it "prevents access by non-admins" do
      allow_api_access FactoryBot(:user)
      get :edit, id: 1, format: "json"
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "update" do
    context "search_criterions" do
      let(:stb) do
        FactoryBot(:state_toggle_button, module_type: 'Shipment',
                                      date_attribute: 'shp_canceled_date',
                                      user_attribute: 'shp_canceled_by')
      end

      let(:stb_new_criteria) do
        [{"mfid" => "prod_uid",
          "label" => "Unique Identifier",
          "operator" => "eq",
          "value" => "x",
          "datatype" => "string",
          "include_empty" => false}]
      end

      before do
        stb.search_criterions << FactoryBot(:search_criterion, model_field_uid: "ent_brok_ref",
                                                            "operator" => "eq",
                                                            "value" => "w",
                                                            "include_empty" => true)
      end

      it "replaces search criterions for admins" do
        put :update, id: stb.id, stb: {}, criteria: stb_new_criteria
        stb.reload
        criteria = stb.search_criterions
        new_criterion = (criteria.first.json user).to_json

        expect(criteria.count).to eq 1
        expect(new_criterion).to eq stb_new_criteria.first.to_json
        expect(JSON.parse(response.body)["ok"]).to eq "ok"
      end

      it "prevents access by non-admins" do
        allow_api_access FactoryBot(:user)
        put :update, id: stb.id, stb: {}, criteria: stb_new_criteria
        stb.reload
        criteria = stb.search_criterions
        expect(criteria.count).to eq 1
        expect(criteria.first.model_field_uid).to eq "ent_brok_ref"
        expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
      end
    end

    context "standard fields" do
      let(:stb) do
        FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by',
                                      permission_group_system_codes: "CODE",
                                      activate_text: "activate!",
                                      activate_confirmation_text: "activate sure?",
                                      deactivate_text: "deactivate!",
                                      deactivate_confirmation_text: "deactivate sure?")
      end
      let(:new_params) do
        {module_type: "Product",
         permission_group_system_codes: "CODE UPDATED",
         activate_text: "activate! updated",
         activate_confirmation_text: "activate sure? updated",
         deactivate_text: "deactivate! updated",
         deactivate_confirmation_text: "deactivate sure? updated"}
      end

      it "replaces other fields for admins, except module_type" do
        put :update, id: stb.id, stb: new_params, criteria: {}
        stb.reload

        expect(stb.module_type).to eq "Shipment"
        expect(stb.activate_text).to eq "activate! updated"
        expect(stb.activate_confirmation_text).to eq "activate sure? updated"
        expect(stb.deactivate_text).to eq "deactivate! updated"
        expect(stb.deactivate_confirmation_text).to eq "deactivate sure? updated"
      end

      it "prevents access by non-admins" do
        allow_api_access FactoryBot(:user)
        put :update, id: stb.id, stb: new_params, criteria: {}
        stb.reload

        expect(stb.activate_text).to eq "activate!"
        expect(stb.activate_confirmation_text).to eq "activate sure?"
        expect(stb.deactivate_text).to eq "deactivate!"
        expect(stb.deactivate_confirmation_text).to eq "deactivate sure?"
      end
    end

    context "mfs and cdefs" do
      let!(:stb) { FactoryBot(:state_toggle_button, user_attribute: "ord_closed_by", date_custom_definition: FactoryBot(:custom_definition))}
      let!(:new_cdef) { FactoryBot(:custom_definition) }

      context "for admins" do
        it "updates mfs/cdefs with existing values" do
          put :update, id: stb.id, stb: {user_attribute: "ord_accepted_by", date_custom_definition_id: new_cdef.id }, criteria: {}
          stb.reload

          expect(stb.user_attribute).to eq "ord_accepted_by"
          expect(stb.date_custom_definition).to eq new_cdef
        end

        it "sets complementary mfs/cdefs to nil" do
          put :update, id: stb.id, stb: {user_custom_definition_id: new_cdef.id, date_attribute: "ord_created_at" }, criteria: {}
          stb.reload

          expect(stb.user_attribute).to be_nil
          expect(stb.date_custom_definition).to be_nil
          expect(stb.user_custom_definition).to eq new_cdef
          expect(stb.date_attribute).to eq "ord_created_at"
        end

        it "prevents date mf and cdef from being set at the same time" do
          current_cdef = stb.date_custom_definition
          put :update, id: stb.id, stb: {date_attribute: "ord_accepted_at", date_custom_definition_id: new_cdef.id }, criteria: {}
          stb.reload
          expect(stb.date_attribute).to be_nil
          expect(stb.date_custom_definition).to eq current_cdef
          expect(JSON.parse(response.body)["errors"]).to include "You cannot set both date/user fields at the same time."
        end

        it "prevents user mf and cdef from being set at the same time" do
          put :update, id: stb.id, stb: {user_attribute: "ord_accepted_by", user_custom_definition_id: new_cdef.id }, criteria: {}
          stb.reload
          expect(stb.user_attribute).to eq "ord_closed_by"
          expect(stb.user_custom_definition).to be_nil
          expect(JSON.parse(response.body)["errors"]).to include "You cannot set both date/user fields at the same time."
        end
      end

      context "for non-admins" do
        it "doesn't update mfs/cdefs" do
          allow_api_access FactoryBot(:user)
          current_cdef = stb.date_custom_definition
          put :update, id: stb.id, stb: {user_attribute: "ord_accepted_by", date_custom_definition_id: new_cdef.id }, criteria: {}
          stb.reload

          expect(stb.user_attribute).to eq "ord_closed_by"
          expect(stb.date_custom_definition).to eq current_cdef
        end
      end
    end
  end

  describe "destroy" do
    let!(:stb) { FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by') }

    it "deletes STB for an admin" do
      delete :destroy, id: stb.id
      expect(StateToggleButton.count).to eq 0
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    it "prevents access by non-admins" do
      allow_api_access FactoryBot(:user)
      delete :destroy, id: stb.id
      expect(StateToggleButton.count).to eq 1
      expect(JSON.parse(response.body)["errors"]).to include "Access denied."
    end
  end

  describe "get_mf_digest" do
    it "returns hash containing stb, search criteria, user and date mfs/cdefs" do
      stb = instance_double("stb")
      ctrl = described_class.new

      sc_mfs = instance_double("sc_mfs")
      user_mfs = instance_double "user_mfs"
      user_cdefs = instance_double "user_cdefs"
      date_mfs = instance_double "date_mfs"
      date_cdefs = instance_double "date_cdefs"

      expect(ctrl).to receive(:get_sc_mfs).with(stb).and_return sc_mfs
      expect(ctrl).to receive(:get_user_and_date_mfs).with(stb).and_return [user_mfs, date_mfs]
      expect(ctrl).to receive(:get_user_and_date_cdefs).with(stb).and_return [user_cdefs, date_cdefs]

      expect(ctrl.get_mf_digest(stb)).to eq({sc_mfs: sc_mfs, user_mfs: user_mfs, user_cdefs: user_cdefs, date_mfs: date_mfs, date_cdefs: date_cdefs})
    end
  end

  describe "get_user_and_date_mfs" do
    it "returns two arrays of model fields associated with button's module, the second including only those of type date/datetime" do
      stb = FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by')

      user_list, date_list = described_class.new.get_user_and_date_mfs(stb)
      # Just make sure the list includes a known date field and user field and does not include a field we know is not either
      expect(user_list).to include({mfid: "shp_canceled_by", label: "Canceled By"})
      ref_mf = ModelField.by_uid(:shp_ref)
      # Just make sure the model field actually exists
      expect(ref_mf.blank?).to eq false
      expect(user_list).not_to include({mfid: "shp_ref", label: ref_mf.label})
      expect(date_list).to include({mfid: "shp_canceled_date", label: "Canceled Date"})
      expect(date_list).not_to include({mfid: "shp_ref", label: ref_mf.label})
    end
  end

  describe "get_sc_mfs" do
    it "takes the model fields associated with a button's module returning only the mfid, label, and datatype fields" do
      stb = FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by')
      mfs = described_class.new.get_sc_mfs stb
      expect(mfs.find {|mf| mf[:mfid] == :shp_ref}).to eq({mfid: :shp_ref, label: "Reference Number", datatype: :string })
    end
  end

  describe "get_user_and_date_cdefs" do
    it "returns two arrays of cdefs associated with the button's module, the first including only those of user_type, the second only those of datetime" do
      stb = FactoryBot(:state_toggle_button, module_type: 'Shipment', date_attribute: 'shp_canceled_date', user_attribute: 'shp_canceled_by')
      user = FactoryBot(:custom_definition, module_type: "Shipment", data_type: "integer", is_user: true, label: "QA Hold By")
      date = FactoryBot(:custom_definition, module_type: "Shipment", data_type: "datetime", label: "QA Hold Date")
      FactoryBot(:custom_definition, module_type: "Shipment", data_type: "integer", label: "Foo")

      user_list, date_list = described_class.new.get_user_and_date_cdefs(stb)
      expect(user_list).to eq [{cdef_id: user.id, label: "QA Hold By"}]
      expect(date_list).to eq [{cdef_id: date.id, label: "QA Hold Date"}]
    end
  end
end