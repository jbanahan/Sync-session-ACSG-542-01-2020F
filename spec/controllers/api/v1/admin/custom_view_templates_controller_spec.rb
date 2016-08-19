require 'spec_helper'

describe Api::V1::Admin::CustomViewTemplatesController do
  before do
    @u = Factory(:sys_admin_user)
    Factory(:custom_view_template, module_type: "Product")
    allow_api_user @u
    use_json
  end

  describe :edit do
    it "renders template JSON for a sys-admin" do
      mf_collection = [{:mfid=>:prod_attachment_count, :label=>"Attachment Count", :datatype=>:integer}, 
                       {:mfid=>:prod_attachment_types, :label=>"Attachment Types", :datatype=>:string}]
      cvt = CustomViewTemplate.first
      cvt.search_criterions << Factory(:search_criterion)
      described_class.any_instance.should_receive(:get_mf_digest).with(cvt).and_return mf_collection
      get :edit, id: cvt.id
      expect(response.body).to eq({template: cvt, criteria: cvt.search_criterions.map{ |sc| sc.json(@u) }, model_fields: mf_collection}.to_json)
    end

    it "prevents access by non-sys-admins" do
      allow_api_access Factory(:user)
      get :edit, id: 1
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})

      allow_api_access Factory(:admin_user)
      get :edit, id: 1
      expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
    end
  end

  describe :update do
    before(:each) do
      @cvt_new_criteria = [{"mfid"=>"prod_uid", "label"=>"Unique Identifier", "operator"=>"eq", "value"=>"x", "datatype"=>"string", "include_empty"=>false}]
      @cvt = CustomViewTemplate.first
      @cvt.update_attributes(module_type: "original module_type", template_identifier: "original template identifier", template_path:"/original/template/path")
      @cvt.search_criterions << Factory(:search_criterion, model_field_uid: "ent_brok_ref", "operator"=>"eq", "value"=>"w", "include_empty"=>true)
    end
    
    it "replaces basic fields and search criterions for a sys-admin, leaves module_type unchanged" do
      
      put :update, id: @cvt.id, cvt: {module_type: "new module_type", template_identifier: "new template identifier", template_path: "/new/template/path"}, criteria: @cvt_new_criteria
      @cvt.reload
      criteria = @cvt.search_criterions
      new_criterion = (criteria.first.json @u).to_json
      
      expect(@cvt.module_type).to eq "original module_type"
      expect(@cvt.template_identifier).to eq "new template identifier"
      expect(@cvt.template_path).to eq "/new/template/path"
      expect(criteria.count).to eq 1
      expect(new_criterion).to eq (@cvt_new_criteria.first).to_json
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    context "with non-sys-admins" do
      after(:each) do
        expect(@cvt.template_identifier).to eq "original template identifier"
        expect(@cvt.template_path).to eq "/original/template/path"
        expect(@criteria.count).to eq 1
        expect(@criteria.first.model_field_uid).to eq "ent_brok_ref"
        expect(JSON.parse(response.body)).to eq({"errors"=>["Access denied."]})
      end

      it "prevents access by regular admins" do
        allow_api_access Factory(:admin_user)
        put :update, id: @cvt.id, criteria: @cvt_new_criteria
        @cvt.reload
        @criteria = @cvt.search_criterions
      end

      it "prevents access by everyone else" do
        allow_api_access Factory(:user)
        put :update, id: @cvt.id, criteria: @cvt_new_criteria
        @cvt.reload
        @criteria = @cvt.search_criterions
      end
    end
  end

  describe :get_mf_digest do
    it "takes the model fields associated with a template's module returns only the mfid, label, and datatype fields" do
      cvt = Factory(:custom_view_template, module_type: "Product")
      mfs = described_class.new.get_mf_digest cvt
      expect(mfs.find{|mf| mf[:mfid] == :prod_uid}).to eq({:mfid => :prod_uid, label: "Unique Identifier", :datatype => :string })
    end
  end
end