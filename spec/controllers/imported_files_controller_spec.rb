require 'spec_helper'

describe ImportedFilesController do
  
  before :each do 
    @u = Factory(:user)
    activate_authlogic
    UserSession.create! @u
  end
  describe 'show' do
    it 'should apply search filters' do
      fir = Factory(:file_import_result, :imported_file=>Factory(:imported_file, :user=>@u))
      f = fir.imported_file
      sc = f.search_criterions.create!(:operator=>"eq",:value=>"x",:model_field_uid=>"prod_uid") 
      FileImportResult.any_instance.should_receive(:changed_objects).with(duck_type(:all)).and_return(Product.where("1=1"))
      get :show, :id=>f.id
      response.should be_success
      assigns(:filters).should have(1).item
      assigns(:filters).first.should == sc
    end
  end
  describe 'filter' do
    before :each do 
      @imported_file = Factory(:imported_file,:user=>@u,:module_type=>"Product")
    end
    it 'should save filters' do
      p = {"id"=>@imported_file.id,"imported_file"=>{"search_criterions_attributes"=>{"0"=>{"model_field_uid"=>"prod_uid","operator"=>"eq","value"=>"x"}}}}
      post :filter, p
      f = ImportedFile.find @imported_file.id
      f.should have(1).search_criterions
      sc = f.search_criterions.first
      sc.model_field_uid.should == "prod_uid"
      sc.operator.should == "eq"
      sc.value.should == "x"
    end
    it 'should not save other attributes' do
      p = {"id"=>@imported_file.id,"imported_file"=>{"module_type"=>"ABC","search_criterions_attributes"=>{"0"=>{"model_field_uid"=>"prod_uid","operator"=>"eq","value"=>"x"}}}}
      post :filter, p
      f = ImportedFile.find @imported_file.id
      f.module_type.should == "Product"
    end
    it 'should replace filters' do
      @imported_file.search_criterions.create!(:model_field_uid=>"prod_name",:operator=>"sw",:value=>"q")
      p = {"id"=>@imported_file.id,"imported_file"=>{"search_criterions_attributes"=>{"0"=>{"model_field_uid"=>"prod_uid","operator"=>"eq","value"=>"x"}}}}
      post :filter, p
      f = ImportedFile.find @imported_file.id
      f.should have(1).search_criterions
      sc = f.search_criterions.first
      sc.model_field_uid.should == "prod_uid"
      sc.operator.should == "eq"
      sc.value.should == "x"
    end
    
  end
  describe 'show_email_file' do
    it 'should run sucessfully' do
      f = Factory(:imported_file, :user=>@u)
      get :show_email_file, :id=>f.id
      response.should be_success
    end
    it 'should not allow a user who cannot view the file' do
      other_user = Factory(:user)
      f = Factory(:imported_file, :user=>other_user)
      get :show_email_file, :id=>f.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end
  describe 'email_file' do
    before :each do
      @file = Factory(:imported_file, :user=>@u)
      @to_address = 'a@b.c'
      @subject = 'test subject'
      @body = "test\nbody"
      @params = {:id=>@file.id, :to=>@to_address, :subject=>@subject, :body=>@body}
      ImportedFile.should_receive(:find).and_return(@file)
    end
    it 'should send file' do
      @file.should_receive(:delay).and_return(@file)
      @file.should_receive(:email_updated_file).with(@u,@to_address,'',@subject,@body,{})
      post :email_file, @params
      response.should redirect_to imported_file_path(@file)
      flash[:notices].should include "The file will be processed and sent shortly."
    end
    it 'should require to address' do
      @file.should_not_receive(:email_updated_file)
      @params[:to] = ""
      post :email_file, @params
      response.should be_redirect
      flash[:errors].should == [ "You must include a \"To\" address." ]
    end
    it 'should not allow if you cannot view the file' do
      @file.should_not_receive(:email_updated_file)
      @file.should_receive(:can_view?).with(@u).and_return(false)
      post :email_file, @params
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end
end
