describe Api::V1::Admin::CustomViewTemplatesController do
  let(:user) { Factory(:sys_admin_user) }

  before do
    Factory(:custom_view_template, module_type: "Product")
    allow_api_user user
    use_json
  end

  describe "edit" do
    it "renders template JSON for a sys-admin" do
      mf_collection = [{mfid: :prod_attachment_count, label: "Attachment Count", datatype: :integer},
                       {mfid: :prod_attachment_types, label: "Attachment Types", datatype: :string}]
      cvt = CustomViewTemplate.first
      cvt.search_criterions << Factory(:search_criterion)
      expect_any_instance_of(described_class).to receive(:get_mf_digest).with(cvt).and_return mf_collection
      get :edit, id: cvt.id
      expect(response.body).to eq({template: cvt, criteria: cvt.search_criterions.map { |sc| sc.json(user) }, model_fields: mf_collection}.to_json)
    end

    it "prevents access by non-sys-admins" do
      allow_api_access Factory(:user)
      get :edit, id: 1
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})

      allow_api_access Factory(:admin_user)
      get :edit, id: 1
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "update" do
    let(:custom_view_template_criteria) do
      [{"mfid" => "prod_uid", "label" => "Unique Identifier", "operator" => "eq", "value" => "x", "datatype" => "string", "include_empty" => false}]
    end

    let!(:custom_view_template) do
      cvt = CustomViewTemplate.first
      cvt.update(module_type: "original module_type", template_identifier: "original template identifier", template_path: "/original/template/path")
      cvt.search_criterions << Factory(:search_criterion, model_field_uid: "ent_brok_ref", "operator" => "eq", "value" => "w", "include_empty" => true)
      cvt
    end

    it "replaces basic fields and search criterions for a sys-admin, leaves module_type unchanged" do
      put :update, id: custom_view_template.id, cvt: {module_type: "new module_type", template_identifier: "new template identifier",
                                                      template_path: "/new/template/path"},
                   criteria: custom_view_template_criteria

      custom_view_template.reload
      criteria = custom_view_template.search_criterions
      new_criterion = (criteria.first.json user).to_json

      expect(custom_view_template.module_type).to eq "original module_type"
      expect(custom_view_template.template_identifier).to eq "new template identifier"
      expect(custom_view_template.template_path).to eq "/new/template/path"
      expect(criteria.count).to eq 1
      expect(new_criterion).to eq custom_view_template_criteria.first.to_json
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    context "with non-sys-admins" do
      it "prevents access by regular admins" do
        allow_api_access Factory(:admin_user)
        put :update, id: custom_view_template.id, criteria: custom_view_template_criteria
        custom_view_template.reload
        criteria = custom_view_template.search_criterions
        expect(custom_view_template.template_identifier).to eq "original template identifier"
        expect(custom_view_template.template_path).to eq "/original/template/path"
        expect(criteria.count).to eq 1
        expect(criteria.first.model_field_uid).to eq "ent_brok_ref"
        expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
      end

      it "prevents access by everyone else" do
        allow_api_access Factory(:user)
        put :update, id: custom_view_template.id, criteria: custom_view_template_criteria
        custom_view_template.reload
        criteria = custom_view_template.search_criterions
        expect(custom_view_template.template_identifier).to eq "original template identifier"
        expect(custom_view_template.template_path).to eq "/original/template/path"
        expect(criteria.count).to eq 1
        expect(criteria.first.model_field_uid).to eq "ent_brok_ref"
        expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
      end
    end
  end

  describe "get_mf_digest" do
    it "takes the model fields associated with a template's module returns only the mfid, label, and datatype fields" do
      cvt = Factory(:custom_view_template, module_type: "Product")
      mfs = described_class.new.get_mf_digest cvt
      expect(mfs.find {|mf| mf[:mfid] == :prod_uid}).to eq({mfid: :prod_uid, label: "Unique Identifier", datatype: :string })
    end
  end
end