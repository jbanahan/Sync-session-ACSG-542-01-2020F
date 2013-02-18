require 'spec_helper'

describe ProductsController do
  before :each do
    activate_authlogic
    @user = Factory(:importer_user,:product_edit=>true,:product_view=>true)
    @other_importer = Factory(:company,:importer=>true)
    @linked_importer = Factory(:company,:importer=>true)
    @user.company.linked_companies << @linked_importer
    UserSession.create! @user
  end
  describe :create do
    it "should fail if not master and importer_id is not current company or linked company" do
      post :create, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@other_importer.id}
      flash[:errors].first.should == "You do not have permission to set importer to company #{@other_importer.id}"
    end
    it "should pass if importer_id is current company" do
      post :create, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@user.company.id}
      p = Product.first
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @user.company
    end
    it "should pass if importer_id is linked company" do
      post :create, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@linked_importer.id}
      p = Product.first
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @linked_importer
    end
  end
  describe :update do
    before :each do 
      @product = Factory(:product,:importer=>@user.company)
    end
    it "should fail if not master and importer_id is not current company or linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@other_importer.id}
      flash[:errors].first.should == "You do not have permission to set importer to company #{@other_importer.id}"
    end
    it "should pass if importer_id is linked company" do
      put :update, 'id'=>@product.id, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@linked_importer.id}
      p = Product.find @product.id
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @linked_importer
    end
    it "should pass if importer_id is current company" do
      put :update, 'id'=>@product.id, 'product'=>{'unique_identifier'=>'abc123455_pccreate','importer_id'=>@user.company.id}
      p = Product.find @product.id
      p.unique_identifier.should == "abc123455_pccreate"
      p.importer.should == @user.company
    end
  end

  describe :bulk_update_classifications do
    before :each do
      @user.update_attributes(:classification_edit=>true)
      MasterSetup.any_instance.should_receive(:classification_enabled).at_least(:once).and_return true
    end

    it "should allow user to bulk update classifications" do
      delay = double
      p = {"k1"=>"v1", "k2"=>"v2"}
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:go_serializable) do |args, id| 
        json = JSON.parse(args)
        json["k1"].should == "v1"
        json["k2"].should == "v2"
        id.should == @user.id
      end

      request.env["HTTP_REFERER"] = "http://www.test.com?force_search=true&key=val" 
      post :bulk_update_classifications, p
      flash[:notices].should == ["These products will be updated in the background.  You will receive a system message when they're ready."]
      response.should redirect_to("http://www.test.com?key=val")
    end
    
    it "should redirect to products_path with no referer" do
      delay = double
      OpenChain::BulkUpdateClassification.should_receive(:delay).and_return delay
      delay.should_receive(:go_serializable)
      request.env["HTTP_REFERER"] = nil
      post :bulk_update_classifications
      response.should redirect_to(products_path)
    end
  end
end
