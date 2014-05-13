require 'spec_helper'

describe ImportedFilesController do
  
  before :each do 
    @u = Factory(:user)

    sign_in_as @u
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
      dont_find = Factory(:product)
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
      r['file_import_result'].should == {'id'=>fir.id}
    end
    it "should return search_criterions" do
      f = Factory(:imported_file,:user=>@u)
      f.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'X')
      f.search_criterions.create!(:model_field_uid=>'prod_name',:operator=>'sw',:value=>'N')
      get :show, :id=>f.id, :format=>:json
      response.should be_success
      r = JSON.parse response.body
      crits = r['search_criterions']
      crits.should have(2).criterions
      crits[0].should == {'mfid'=>'prod_uid','operator'=>'eq','value'=>'X','include_empty'=>false,'datatype'=>'string','label'=>'Unique Identifier'}
      crits[1].should == {'mfid'=>'prod_name','operator'=>'sw','value'=>'N','include_empty'=>false,'datatype'=>'string','label'=>'Name'}
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
    it "should return available model fields" do
      f = Factory(:imported_file,:user=>@u,:module_type=>"Product")
      get :show, :id=>f.id, :format=>:json
      response.should be_success
      r = JSON.parse response.body
      r['model_fields'].collect {|m| m['mfid']}.include?('prod_uid')
    end
  end
  describe 'results' do
    context :search_runs do
      before :each do
        @f = Factory(:imported_file,:user=>@u)
        fir = Factory(:file_import_result,:imported_file=>@f,:finished_at=>1.minute.ago)
      end
      it "should create search run" do
        get :results, :id=>@f.id, :format=>:json
        response.should be_success
        @f.search_runs.first.should_not be_nil
        r = JSON.parse response.body
        expect(r['search_run_id']).to eq @f.search_runs.first.id
      end
      it "should update last accessed on search run" do
        @f.search_runs.create!(:last_accessed=>1.day.ago)
        get :results, :id=>@f.id, :format=>:json
        response.should be_success
        @f.reload
        @f.search_runs.first.last_accessed.should > 1.minute.ago
      end

    end
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
      f.search_columns.create!(:model_field_uid=>'prod_changed_at')
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
      r['columns'].should == [ModelField.find_by_uid('prod_uid').label,ModelField.find_by_uid('prod_name').label, ModelField.find_by_uid('prod_changed_at').label]
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

    it "should limit page size to 10 for old IE versions" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      Product.stub(:search_where).and_return("1=1")
      p1 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      fir.change_records.create!(:recordable=>p1)

      # The important bit here is the 10 at the end of the with parameters
      ImportedFilesController.any_instance.should_receive(:execute_query_to_hash).with(an_instance_of(SearchQuery), @u, 1, 10).and_return({})
      get :results, :id=>f.id, :format=>:json
      response.should be_success
    end

    it "should limit page size to 100 for all other browsers" do
      Product.stub(:search_where).and_return("1=1")
      p1 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      fir.change_records.create!(:recordable=>p1)

      # The important bit here is the 100 at the end of the with parameters
      ImportedFilesController.any_instance.should_receive(:execute_query_to_hash).with(an_instance_of(SearchQuery), @u, 1, 100).and_return({})
      get :results, :id=>f.id, :format=>:json
      response.should be_success
    end
  end
  describe 'update_search_criterions' do
    before :each do
      @f = Factory(:imported_file, :user=>@u)
    end
    it "should add criterion" do
      post :update_search_criterions, :id=>@f.id, :imported_file=>{:id=>@f.id,:search_criterions=>[{:mfid=>'prod_uid',:operator=>'eq',:value=>'X'},{:mfid=>'prod_name',:operator=>'sw',:value=>'Y'}]}
      response.should be_success
      JSON.parse(response.body)['ok'].should == 'ok'
      @f.should have(2).search_criterions
      @f.search_criterions.where(:model_field_uid=>'prod_uid',:value=>'X',:operator=>'eq').should have(1).item
      @f.search_criterions.where(:model_field_uid=>'prod_name',:value=>'Y',:operator=>'sw').should have(1).item
    end
    it "should remove criterion not in params" do
      @f.search_criterions.create!(:model_field_uid=>'prod_class_count',:value=>2,:operator=>'eq')
      post :update_search_criterions, :id=>@f.id, :imported_file=>{:id=>@f.id,:search_criterions=>[{:mfid=>'prod_uid',:operator=>'eq',:value=>'X'},{:mfid=>'prod_name',:operator=>'sw',:value=>'Y'}]}
      response.should be_success
      JSON.parse(response.body)['ok'].should == 'ok'
      @f.should have(2).search_criterions
      @f.search_criterions.where(:model_field_uid=>'prod_uid',:value=>'X',:operator=>'eq').should have(1).item
      @f.search_criterions.where(:model_field_uid=>'prod_name',:value=>'Y',:operator=>'sw').should have(1).item
    end
    it "should 404 if user cannot view file" do
      ImportedFile.any_instance.stub(:can_view?).and_return false
      lambda { post :update_search_criterions, :id=>@f.id, :imported_file=>{:id=>@f.id,:search_criterions=>[{:mfid=>'prod_uid',:operator=>'eq',:value=>'X'},{:mfid=>'prod_name',:operator=>'sw',:value=>'Y'}]}}.should raise_error ActionController::RoutingError
      @f.reload
      @f.search_criterions.should be_empty
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

  describe :legacy_javascripts? do
    it "should not include legacy javascripts" do
      ImportedFilesController.new.legacy_javascripts?.should be_false
    end
  end
end
