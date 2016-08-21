require 'spec_helper'

describe CommercialInvoiceMapsController do
  before :each do
    @u = Factory(:user,:admin=>true)

    sign_in_as @u
  end
  describe "index" do
    it "should reject if user is admin not" do
      allow_any_instance_of(User).to receive(:admin?).and_return(false)
      get :index
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
    end
    it "should load all mappings" do
      2.times { Factory(:commercial_invoice_map)}
      get :index
      expect(response).to be_success
      expect(assigns(:maps).size).to eq(2)
    end
  end
  describe "update_all" do
    it "should reject if user is not admin" do
      allow_any_instance_of(User).to receive(:admin?).and_return(false)
      post :update_all
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
    end
    it "should add new items" do
      p = {"map"=>{"1"=>{"src"=>"prod_uid","dest"=>"cil_part_number"},
        "2"=>{"src"=>"shp_ref","dest"=>"ci_invoice_number"}
      }}
      post :update_all, p
      expect(response).to redirect_to commercial_invoice_maps_path
      expect(CommercialInvoiceMap.all.size).to eq(2)
      expect(CommercialInvoiceMap.find_by_source_mfid("prod_uid").destination_mfid).to eq("cil_part_number")
      expect(CommercialInvoiceMap.find_by_source_mfid("shp_ref").destination_mfid).to eq("ci_invoice_number")
    end
    it "should delete existing items" do
      #this one will be replaced
      Factory(:commercial_invoice_map,:source_mfid=>"prod_uid",:destination_mfid=>"cil_part_number") 
      #this one will be deleted
      Factory(:commercial_invoice_map,:source_mfid=>"ord_ord_num",:destination_mfid=>"cil_po_number")

      p = {"map"=>{"1"=>{"src"=>"prod_uid","dest"=>"cil_part_number"},
        "2"=>{"src"=>"shp_ref","dest"=>"ci_invoice_number"}
      }}
      post :update_all, p
      expect(response).to redirect_to commercial_invoice_maps_path
      expect(CommercialInvoiceMap.all.size).to eq(2)
      expect(CommercialInvoiceMap.find_by_source_mfid("prod_uid").destination_mfid).to eq("cil_part_number")
      expect(CommercialInvoiceMap.find_by_source_mfid("shp_ref").destination_mfid).to eq("ci_invoice_number")
    end
  end
end
