require 'spec_helper'

describe ImportedFilesController do
  
  before :each do 
    @u = Factory(:user)
    activate_authlogic
    UserSession.create! @u
  end
  describe 'show' do
    it 'should pass for html' do
      get :show, :id=>1
      response.should redirect_to "/imported_files/show_angular#/1"
    end
    it "should 404 for json & imported file that user can't view" do
      FileImportResult.any_instance.stub(:can_view?).and_return false
      f = Factory(:imported_file)
      lambda {get :show, :id=>f.id,:format=>:json}.should raise_error ActionController::RoutingError
    end
    it "should return json for user who can view" do
      FileImportResult.any_instance.stub(:time_to_process).and_return(89)
      FileImportResult.any_instance.stub(:error_count).and_return(61)
      p1 = Factory(:product)
      p2 = Factory(:product)
      f = Factory(:imported_file,:user=>@u)
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      [p1,p2].each {|p| fir.change_records.create!(:recordable=>p)}
      fir.change_records.create!(:recordable=>p1) #extra file row
      get :show, :id=>f.id, :format=>:json
      response.should be_success
      r = JSON.parse response.body
      r['id'].should == f.id
      r['uploaded_at'].should == 0.seconds.ago.strftime("%Y-%m-%d %H:%M")
      r['uploaded_by'].should == @u.full_name
      r['total_rows'].should == 3
      r['total_records'].should == 2
      r['last_processed'].should == finished_at.strftime("%Y-%m-%d %H:%M")
      r['time_to_process'].should == 89
      r['processing_error_count'].should == 61
      r['current_user'].should == {'id'=>@u.id,'full_name'=>@u.full_name,'email'=>@u.email}
    end
    it "should return available countries" do
      f = Factory(:imported_file,:user=>@u)
      us = Factory(:country,:iso_code=>"US",:name=>"USA",:import_location=>true,:classification_rank=>2)
      ca = Factory(:country,:iso_code=>"CA",:name=>"Canada",:import_location=>true,:classification_rank=>1)
      get :show, :id=>f.id, :format=>:json
      response.should be_success
      r = JSON.parse response.body
      r['available_countries'].should == [
        {'iso_code'=>'CA','name'=>'Canada','id'=>ca.id},
        {'iso_code'=>'US','name'=>'USA','id'=>us.id}
      ]
    end
  end
  describe 'results' do
    it "should 404 if user can't view" do
      FileImportResult.any_instance.stub(:can_view?).and_return false
      f = Factory(:imported_file)
      lambda {get :results, :id=>f.id,:format=>:json}.should raise_error ActionController::RoutingError
    end
    it "should return json" do
      Product.stub(:search_where).and_return("1=1")
      p1 = Factory(:product)
      p2 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      [p1,p2].each {|p| fir.change_records.create!(:recordable=>p)}
      fir.change_records.create!(:recordable=>p1) #extra file row
      get :results, :id=>f.id, :format=>:json
      response.should be_success
      r = JSON.parse response.body
      r['id'].should == f.id
      r['page'].should == 1
      r['name'].should == f.attached_file_name
      r['columns'].should == [ModelField.find_by_uid('prod_uid').label,ModelField.find_by_uid('prod_name').label]
      r['rows'].size.should == 2
      r['rows'].first['id'].should == p1.id
    end
    it "should restrict results to products in file" do
      Product.stub(:search_where).and_return("1=1")
      p1 = Factory(:product)
      p2 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      fir.change_records.create!(:recordable=>p1)
      get :results, :id=>f.id, :format=>:json
      response.should be_success
      r = JSON.parse response.body
      r['rows'].size.should == 1
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
