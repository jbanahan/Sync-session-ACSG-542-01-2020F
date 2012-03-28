require 'spec_helper'

describe CommercialInvoiceMapsController do
  before :each do
    @u = Factory(:user,:admin=>true)
    activate_authlogic
    UserSession.create! @u
  end
  describe "index" do
    it "should reject if user is admin not" do
      User.any_instance.stub(:admin?).and_return(false)
      get :index
      response.should redirect_to request.referrer
      flash[:errors].should have(1).item
    end
    it "should load all mappings" do
      2.times { Factory(:commercial_invoice_map)}
      get :index
      response.should be_success
      assigns(:maps).should have(2).items
    end
  end
  describe "update_all" do
    it "should reject if user is not admin" do
      User.any_instance.stub(:admin?).and_return(false)
      post :update_all
      response.should redirect_to request.referrer
      flash[:errors].should have(1).item
    end
    it "should add new items" do
      p = {"map"=>{"1"=>{"src"=>"prod_uid","dest"=>"cil_part_number"},
        "2"=>{"src"=>"shp_ref","dest"=>"ci_invoice_number"}
      }}
      post :update_all, p
      response.should redirect_to commercial_invoice_maps_path
      CommercialInvoiceMap.all.should have(2).items
      CommercialInvoiceMap.find_by_source_mfid("prod_uid").destination_mfid.should == "cil_part_number"
      CommercialInvoiceMap.find_by_source_mfid("shp_ref").destination_mfid.should == "ci_invoice_number"
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
      response.should redirect_to commercial_invoice_maps_path
      CommercialInvoiceMap.all.should have(2).items
      CommercialInvoiceMap.find_by_source_mfid("prod_uid").destination_mfid.should == "cil_part_number"
      CommercialInvoiceMap.find_by_source_mfid("shp_ref").destination_mfid.should == "ci_invoice_number"
    end
  end
end
