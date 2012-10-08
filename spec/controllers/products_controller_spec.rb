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
end
