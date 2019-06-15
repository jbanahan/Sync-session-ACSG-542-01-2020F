describe ImportedFilesController do
  
  before :each do 
    @u = Factory(:user)

    sign_in_as @u
  end
  describe 'show' do
    it 'should pass for html' do
      get :show, :id=>1
      expect(response).to redirect_to "/imported_files/show_angular#/1"
    end
    it "should 404 for json & imported file that user can't view" do
      allow_any_instance_of(FileImportResult).to receive(:can_view?).and_return false
      f = Factory(:imported_file)
      expect {get :show, :id=>f.id,:format=>:json}.to raise_error ActionController::RoutingError
    end
    it "should return json for user who can view" do
      allow_any_instance_of(FileImportResult).to receive(:time_to_process).and_return(89)
      allow_any_instance_of(FileImportResult).to receive(:error_count).and_return(61)
      p1 = Factory(:product)
      p2 = Factory(:product)
      dont_find = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:note=>"nota bene", :search_setup=>Factory(:search_setup, name: "search!"))
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      [p1,p2].each {|p| fir.change_records.create!(:recordable=>p)}
      fir.change_records.create!(:recordable=>p1) #extra file row
      get :show, :id=>f.id, :format=>:json
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r['id']).to eq(f.id)
      expect(r['note']).to eq "nota bene"
      expect(r['uploaded_at']).to eq(0.seconds.ago.strftime("%Y-%m-%d %H:%M"))
      expect(r['uploaded_by']).to eq(@u.full_name)
      expect(r['total_rows']).to eq(3)
      expect(r['last_processed']).to eq(finished_at.strftime("%Y-%m-%d %H:%M"))
      expect(r['time_to_process']).to eq(89)
      expect(r['processing_error_count']).to eq(61)
      expect(r['current_user']).to eq({'id'=>@u.id,'full_name'=>@u.full_name,'email'=>@u.email})
      expect(r['file_import_result']).to eq({'id'=>fir.id})
      expect(r['search_setup_name']).to eq "search!"
    end
    it "should return search_criterions" do
      f = Factory(:imported_file,:user=>@u)
      f.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'X')
      f.search_criterions.create!(:model_field_uid=>'prod_name',:operator=>'sw',:value=>'N')
      get :show, :id=>f.id, :format=>:json
      expect(response).to be_success
      r = JSON.parse response.body
      crits = r['search_criterions']
      expect(crits.size).to eq(2)
      expect(crits[0]).to eq({'mfid'=>'prod_uid','operator'=>'eq','value'=>'X','include_empty'=>false,'datatype'=>'string','label'=>'Unique Identifier'})
      expect(crits[1]).to eq({'mfid'=>'prod_name','operator'=>'sw','value'=>'N','include_empty'=>false,'datatype'=>'string','label'=>'Name'})
    end
    it "should return available countries" do
      f = Factory(:imported_file,:user=>@u)
      us = Factory(:country,:iso_code=>"US",:name=>"USA",:import_location=>true,:classification_rank=>2)
      ca = Factory(:country,:iso_code=>"CA",:name=>"Canada",:import_location=>true,:classification_rank=>1)
      get :show, :id=>f.id, :format=>:json
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r['available_countries']).to eq([
        {'iso_code'=>'CA','name'=>'Canada','id'=>ca.id},
        {'iso_code'=>'US','name'=>'USA','id'=>us.id}
      ])
    end
    it "should return available model fields" do
      f = Factory(:imported_file,:user=>@u,:module_type=>"Product")
      get :show, :id=>f.id, :format=>:json
      expect(response).to be_success
      r = JSON.parse response.body
      r['model_fields'].collect {|m| m['mfid']}.include?('prod_uid')
    end
  end
  describe 'results' do
    context "search_runs" do
      before :each do
        @f = Factory(:imported_file,:user=>@u)
        fir = Factory(:file_import_result,:imported_file=>@f,:finished_at=>1.minute.ago)
      end
      it "should create search run" do
        get :results, :id=>@f.id, :format=>:json
        expect(response).to be_success
        expect(@f.search_runs.first).not_to be_nil
        r = JSON.parse response.body
        expect(r['search_run_id']).to eq @f.search_runs.first.id
      end
      it "should update last accessed on search run" do
        @f.search_runs.create!(:last_accessed=>1.day.ago)
        get :results, :id=>@f.id, :format=>:json
        expect(response).to be_success
        @f.reload
        expect(@f.search_runs.first.last_accessed).to be > 1.minute.ago
      end

    end
    it "should 404 if user can't view" do
      allow_any_instance_of(FileImportResult).to receive(:can_view?).and_return false
      f = Factory(:imported_file)
      expect {get :results, :id=>f.id,:format=>:json}.to raise_error ActionController::RoutingError
    end
    it "should return json" do
      allow(Product).to receive(:search_where).and_return("1=1")
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
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r['id']).to eq(f.id)
      expect(r['page']).to eq(1)
      expect(r['name']).to eq(f.attached_file_name)
      expect(r['columns']).to eq([ModelField.find_by_uid('prod_uid').label,ModelField.find_by_uid('prod_name').label, ModelField.find_by_uid('prod_changed_at').label])
      expect(r['rows'].size).to eq(2)
      expect(r['rows'].first['id']).to eq(p1.id)
    end
    it "should restrict results to products in file" do
      allow(Product).to receive(:search_where).and_return("1=1")
      p1 = Factory(:product)
      p2 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      fir.change_records.create!(:recordable=>p1)
      get :results, :id=>f.id, :format=>:json
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r['rows'].size).to eq(1)
    end

    it "should limit page size to 10 for old IE versions" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      allow(Product).to receive(:search_where).and_return("1=1")
      p1 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      fir.change_records.create!(:recordable=>p1)

      # The important bit here is the 10 at the end of the with parameters
      expect_any_instance_of(ImportedFilesController).to receive(:execute_query_to_hash).with(an_instance_of(SearchQuery), @u, 1, 10).and_return({})
      get :results, :id=>f.id, :format=>:json
      expect(response).to be_success
    end

    it "should limit page size to 100 for all other browsers" do
      allow(Product).to receive(:search_where).and_return("1=1")
      p1 = Factory(:product)
      f = Factory(:imported_file,:user=>@u,:attached_file_name=>'fn.xls')
      f.search_columns.create!(:model_field_uid=>'prod_uid')
      f.search_columns.create!(:model_field_uid=>'prod_name')
      finished_at = 1.minute.ago
      fir = Factory(:file_import_result,:imported_file=>f,:finished_at=>finished_at)
      fir.change_records.create!(:recordable=>p1)

      # The important bit here is the 100 at the end of the with parameters
      expect_any_instance_of(ImportedFilesController).to receive(:execute_query_to_hash).with(an_instance_of(SearchQuery), @u, 1, 100).and_return({})
      get :results, :id=>f.id, :format=>:json
      expect(response).to be_success
    end
  end
  describe 'update_search_criterions' do
    before :each do
      @f = Factory(:imported_file, :user=>@u)
    end
    it "should add criterion" do
      post :update_search_criterions, :id=>@f.id, :imported_file=>{:id=>@f.id,:search_criterions=>[{:mfid=>'prod_uid',:operator=>'eq',:value=>'X'},{:mfid=>'prod_name',:operator=>'sw',:value=>'Y'}]}
      expect(response).to be_success
      expect(JSON.parse(response.body)['ok']).to eq('ok')
      expect(@f.search_criterions.size).to eq(2)
      expect(@f.search_criterions.where(:model_field_uid=>'prod_uid',:value=>'X',:operator=>'eq').size).to eq(1)
      expect(@f.search_criterions.where(:model_field_uid=>'prod_name',:value=>'Y',:operator=>'sw').size).to eq(1)
    end
    it "should remove criterion not in params" do
      @f.search_criterions.create!(:model_field_uid=>'prod_class_count',:value=>2,:operator=>'eq')
      post :update_search_criterions, :id=>@f.id, :imported_file=>{:id=>@f.id,:search_criterions=>[{:mfid=>'prod_uid',:operator=>'eq',:value=>'X'},{:mfid=>'prod_name',:operator=>'sw',:value=>'Y'}]}
      expect(response).to be_success
      expect(JSON.parse(response.body)['ok']).to eq('ok')
      expect(@f.search_criterions.size).to eq(2)
      expect(@f.search_criterions.where(:model_field_uid=>'prod_uid',:value=>'X',:operator=>'eq').size).to eq(1)
      expect(@f.search_criterions.where(:model_field_uid=>'prod_name',:value=>'Y',:operator=>'sw').size).to eq(1)
    end
    it "should 404 if user cannot view file" do
      allow_any_instance_of(ImportedFile).to receive(:can_view?).and_return false
      expect { post :update_search_criterions, :id=>@f.id, :imported_file=>{:id=>@f.id,:search_criterions=>[{:mfid=>'prod_uid',:operator=>'eq',:value=>'X'},{:mfid=>'prod_name',:operator=>'sw',:value=>'Y'}]}}.to raise_error ActionController::RoutingError
      @f.reload
      expect(@f.search_criterions).to be_empty
    end
  end
  describe 'email_file' do
    before :each do
      @file = Factory(:imported_file, :user=>@u)
      @to_address = 'a@b.c'
      @subject = 'test subject'
      @body = "test\nbody"
      @params = {:id=>@file.id, :to=>@to_address, :subject=>@subject, :body=>@body}
      expect(ImportedFile).to receive(:find).and_return(@file)
    end
    it 'should send file' do
      expect(@file).to receive(:delay).and_return(@file)
      expect(@file).to receive(:email_updated_file).with(@u,@to_address,'',@subject,@body,{})
      post :email_file, @params
      expect(response).to redirect_to imported_file_path(@file)
      expect(flash[:notices]).to include "The file will be processed and sent shortly."
    end
    it 'should require to address' do
      expect(@file).not_to receive(:email_updated_file)
      @params[:to] = ""
      post :email_file, @params
      expect(response).to be_redirect
      expect(flash[:errors]).to eq([ "You must include a \"To\" address." ])
    end
    it 'should not allow if you cannot view the file' do
      expect(@file).not_to receive(:email_updated_file)
      expect(@file).to receive(:can_view?).with(@u).and_return(false)
      post :email_file, @params
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "legacy_javascripts?" do
    it "should not include legacy javascripts" do
      expect(ImportedFilesController.new.legacy_javascripts?).to be_falsey
    end
  end
end
