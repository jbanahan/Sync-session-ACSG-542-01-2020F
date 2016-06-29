require 'spec_helper'

describe CustomViewTemplatesController do
  before :each do
    @u = Factory(:user)
    3.times { Factory(:custom_view_template, module_type: "Product") }
    sign_in_as @u
  end

  describe :index do
    it "lists CVTs for a sys-admin" do
      @u.should_receive(:sys_admin?).and_return true
      get :index
      expect(assigns(:templates)).to eq CustomViewTemplate.all
      expect(response).to render_template :index
    end

    it "prevents access by non-sys-admins" do
      @u.should_receive(:sys_admin?).and_return false
      get :index
      expect(assigns(:templates)).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe :new do
    it "renders CVT new view for a sys-admin" do
      @u.should_receive(:sys_admin?).and_return true
      Struct.new("Cm", :class_name)
      cm_arr = ["Product", "Entry", "Order"].map{ |cm_name| Struct::Cm.new(cm_name) }
      CoreModule.should_receive(:all).and_return cm_arr

      get :new
      expect(assigns(:cm_list)).to eq ["Entry", "Order", "Product"]
      expect(assigns(:template)).to be_instance_of CustomViewTemplate
      expect(response).to render_template :new
    end

    it "prevents access by non-sys-admins" do
      @u.should_receive(:sys_admin?).and_return false
      get :new
      expect(assigns(:cm_list)).to be_nil
      expect(assigns(:template)).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe :edit do
    context "HTTP" do
      it "renders the page for a sys-admin" do
        @u.should_receive(:sys_admin?).and_return true
        get :edit, id: CustomViewTemplate.first.id
        expect(response).to render_template :edit
      end
      
      it "prevents access by non-sys-admins" do
        @u.should_receive(:sys_admin?).and_return false
        get :edit, id: CustomViewTemplate.first.id
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include "Only system admins can do this."
      end
    end

    context "JSON" do
      it "renders template JSON for a sys-admin" do
        @u.should_receive(:sys_admin?).and_return true
        mf_collection = [{:mfid=>:prod_attachment_count, :label=>"Attachment Count", :datatype=>:integer}, 
                         {:mfid=>:prod_attachment_types, :label=>"Attachment Types", :datatype=>:string}]
        cvt = CustomViewTemplate.first
        cvt.search_criterions << Factory(:search_criterion)
        described_class.any_instance.should_receive(:get_mf_digest).with(cvt).and_return mf_collection
        get :edit, id: cvt.id, :format => "json"
        expect(response.body).to eq({template: cvt, criteria: cvt.search_criterions.map{ |sc| sc.json(@u) }, model_fields: mf_collection}.to_json)
      end

      it "prevents access by non-sys-admins" do
        @u.should_receive(:sys_admin?).and_return false
        get :edit, id: 1, :format => "json"
        expect(JSON.parse(response.body)["error"]).to eq "You are not authorized to edit this template."
      end
    end

  end
  
  describe :update do
    before(:each) do
      @cvt_new_criteria = [{"mfid"=>"prod_uid", "label"=>"Unique Identifier", "operator"=>"eq", "value"=>"x", "datatype"=>"string", "include_empty"=>false}]
      @cvt = CustomViewTemplate.first
      @cvt.search_criterions << Factory(:search_criterion, model_field_uid: "ent_brok_ref", "operator"=>"eq", "value"=>"w", "include_empty"=>true)
    end
    
    it "replaces search criterions for a sys-admin" do
      @u.should_receive(:sys_admin?).and_return true
      
      put :update, id: @cvt.id, criteria: @cvt_new_criteria
      @cvt.reload
      criteria = @cvt.search_criterions
      new_criterion = (criteria.first.json @u).to_json
      
      expect(criteria.count).to eq 1
      expect(new_criterion).to eq (@cvt_new_criteria.first).to_json
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end

    it "prevents access by non-sys-admins" do
      @u.should_receive(:sys_admin?).and_return false
      put :update, id: @cvt.id, criteria: @cvt_new_criteria
      @cvt.reload
      criteria = @cvt.search_criterions
      expect(criteria.count).to eq 1
      expect(criteria.first.model_field_uid).to eq "ent_brok_ref"
      expect(JSON.parse(response.body)["error"]).to eq "You are not authorized to update this template."
    end
  end

  describe :create do
    it "creates CVT for a sys-admin" do
      @u.should_receive(:sys_admin?).and_return true
      post :create, {template_identifier: "identifier", template_path: "path/to/template", module_type: "Order"}
      cvt =  CustomViewTemplate.last
      expect(cvt.template_identifier).to eq "identifier"
      expect(cvt.template_path).to eq "path/to/template"
      expect(cvt.module_type).to eq "Order"
      expect(response).to redirect_to edit_custom_view_template_path(CustomViewTemplate.last)
    end

    it "prevents access by non-sys-admins" do
      @u.should_receive(:sys_admin?).and_return false
      post :create, {template_identifier: "identifier", template_path: "path/to/template", module_type: "Order"}
      expect(CustomViewTemplate.count).to eq 3
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe :destroy do
    it "deletes CVT for a sys-admin" do
      @u.should_receive(:sys_admin?).and_return true
      delete :destroy, id: CustomViewTemplate.first.id
      expect(CustomViewTemplate.count).to eq 2
      expect(response).to redirect_to(custom_view_templates_path)
    end

    it "prevents access by non-sys-admins" do
      @u.should_receive(:sys_admin?).and_return false
      delete :destroy, id: CustomViewTemplate.first.id
      expect(CustomViewTemplate.count).to eq 3
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
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