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
end