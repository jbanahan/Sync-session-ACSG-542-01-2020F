require 'spec_helper'

describe StateToggleButtonsController do

  let!(:u) { Factory(:user) }
  before { sign_in_as u }
    
  describe "index" do
    let!(:stb) do
      user_cdef = Factory(:custom_definition, data_type: "integer", module_type: "Order", is_user: true, label: "Closed By")
      Factory(:state_toggle_button, user_custom_definition: user_cdef, date_attribute: "ord_closed_at")
    end

    it "lists STBs and user/date-field labels for a sys-admin" do
      expect(u).to receive(:admin?).and_return true
      get :index
      expect(assigns(:buttons)).to eq [{'stb' => stb, 'user_field' => 'Closed By', 'date_field' => 'Closed At'}]
      expect(response).to render_template :index
    end

    it "prevents access by non-sys-admins" do
      expect(u).to receive(:admin?).and_return false
      get :index
      expect(assigns(:buttons)).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only administrators can do this."
    end
  end

  describe "new" do
    it "renders STB new view for an admin" do
      expect(u).to receive(:admin?).and_return true
      cm_prod = instance_double("CoreModule")
      allow(cm_prod).to receive(:class_name).and_return "Product"
      cm_entry = instance_double("CoreModule")
      allow(cm_entry).to receive(:class_name).and_return "Entry"
      cm_order = instance_double("CoreModule")
      allow(cm_order).to receive(:class_name).and_return "Order"

      expect(CoreModule).to receive(:all).and_return [cm_prod, cm_entry, cm_order]
      
      get :new
      expect(assigns(:button)).to be_instance_of StateToggleButton
      expect(assigns(:cm_list)).to eq ["Entry", "Order", "Product"]
      expect(response).to render_template :new
    end

    it "prevents access by non admins" do
      expect(u).to receive(:admin?).and_return false
      get :new
      expect(assigns(:button)).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only administrators can do this."
    end
  end

  describe "create" do
    it "creates STB for an admin" do
      expect(u).to receive(:admin?).and_return true
      post :create, {module_type: "Order"}
      stb =  StateToggleButton.last
      expect(stb.module_type).to eq "Order"
      expect(stb.permission_group_system_codes).to eq "PLACEHOLDER"
      expect(response).to redirect_to edit_state_toggle_button_path(stb)
    end

    it "prevents access by non-admins" do
      expect(u).to receive(:admin?).and_return false
      post :create, {module_type: "Order"}
      expect(StateToggleButton.count).to eq 0
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only administrators can do this."
    end
  end

  describe "edit" do
    let!(:stb) { Factory(:state_toggle_button) }
      it "renders the page for an admin" do
        expect(u).to receive(:admin?).and_return true
        get :edit, id: stb.id
        expect(response).to render_template :edit
      end
      
      it "prevents access by non-admins" do
        expect(u).to receive(:admin?).and_return false
        get :edit, id: stb.id
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include "Only administrators can do this."
      end
  end
end
