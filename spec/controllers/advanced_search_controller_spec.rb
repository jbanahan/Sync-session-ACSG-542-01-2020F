require 'spec_helper'

describe AdvancedSearchController do
  before :each do
    @user = Factory(:master_user,:email=>'a@example.com')

    sign_in_as @user
  end

  describe :destroy do 
    it "should destroy and return id of previous search" do
      old_search = Factory(:search_setup,:module_type=>'Product',:user=>@user)
      new_search = Factory(:search_setup,:module_type=>'Product',:user=>@user)
      delete :destroy, :id=>new_search.id
      JSON.parse(response.body)['id'].should == old_search.id
      SearchSetup.find_by_id(new_search.id).should be_nil
    end
    it "should destroy and create new search if none found" do
      ss = Factory(:search_setup,:user=>@user)
      delete :destroy, :id=>ss.id
      id = JSON.parse(response.body)['id']
      new_ss = SearchSetup.find(id)
      new_ss.user.should == @user
      new_ss.module_type.should == ss.module_type
    end
    it "should not allow destroy of another users search (404)" do
      ss = Factory(:search_setup)
      lambda {delete :destroy, :id=>ss.id}.should raise_error ActionController::RoutingError
      SearchSetup.find_by_id(ss.id).should_not be_nil
    end
  end
  describe :create do
    before :each do
      CoreModule::PRODUCT.stub(:enabled?).and_return(true)
      CoreModule::PRODUCT.stub(:view?).and_return(true)
    end
    it "should create new default search" do
      post :create, :module_type=>"Product"
      response.should be_success
      h = JSON.parse response.body
      ss = SearchSetup.find h['id']
      ss.user.should == @user
      ss.module_type.should == 'Product'
      ss.name.should == "New Search"
    end
    it "should fail if user cannot view module" do
      CoreModule::PRODUCT.stub(:view?).and_return(false)
      lambda {post :create, :module_type=>"Product"}.should raise_error ActionController::RoutingError
      SearchSetup.for_user(@user).should be_empty
    end
    it "should fail if module not specified" do
      lambda {post :create}.should raise_error ActionController::RoutingError
      SearchSetup.for_user(@user).should be_empty
    end
  end
  describe :update do
    before :each do
      @ss = Factory(:search_setup,:name=>"X",:user=>@user,:include_links=>true,:no_time=>false,
        :module_type=>"Product")
    end
    it "should 404 for wrong user" do
      ss = Factory(:search_setup)
      lambda {put :update, :id=>ss.id, :search_setup=>{:name=>'q'}}.should raise_error ActionController::RoutingError 
    end
    it "should update name" do
      put :update, :id=>@ss.id, :search_setup=>{:name=>'Y',:include_links=>false,:no_time=>true} 
      response.should be_success
      @ss.reload
      @ss.name.should == "Y"
      @ss.include_links?.should be_false
      @ss.no_time?.should be_true
    end
    it "should recreate columns" do
      @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
      put :update, :id=>@ss.id, :search_setup=>{:search_columns=>[{:mfid=>'prod_uid',:label=>"UID",:rank=>2},
        {:mfid=>'prod_name',:rank=>1,:label=>'m'},
        {:mfid=>'_blanksomeotherjunk',:rank=>3}
      ]}
      response.should be_success
      @ss.reload
      @ss.should have(3).search_columns
      @ss.search_columns.find_by_rank_and_model_field_uid(1,'prod_name').should_not be_nil
      @ss.search_columns.find_by_rank_and_model_field_uid(2,'prod_uid').should_not be_nil
      @ss.search_columns.find_by_rank_and_model_field_uid(3,'_blank').should_not be_nil
    end
    it "should recreate sorts" do
      @ss.sort_criterions.create!(:model_field_uid=>:prod_uid,:rank=>1,:descending=>false)
      put :update, :id=>@ss.id, :search_setup=>{:sort_criterions=>[
        {:mfid=>'prod_name',:label=>'NM',:rank=>1,:descending=>true},
        {:mfid=>'prod_uid',:label=>'UID',:rank=>2,:descending=>false}
      ]}
      response.should be_success
      @ss.reload
      @ss.should have(2).sort_criterions
      @ss.sort_criterions.find_by_rank_and_model_field_uid(1,'prod_name').should be_descending
      @ss.sort_criterions.find_by_rank_and_model_field_uid(2,'prod_uid').should_not be_descending
    end
    it "should recreate schedules" do
      SearchSetup.any_instance.stub(:can_ftp?).and_return(true)
      @ss.search_schedules.create!(:email_addresses=>"a@example.com")
      put :update, :id=>@ss.id, :search_setup=>{:search_schedules=>[
        {:email_addresses=>'b@example.com',:run_hour=>6,:day_of_month=>1,:download_format=>'xls',
          :run_monday=>true,:run_tuesday=>false,:run_wednesday=>false,:run_thursday=>false,:run_friday=>false,:run_saturday=>false,:run_sunday=>false},
        {:ftp_server=>'ftp.example.com',:ftp_username=>'user',:ftp_password=>'pass',:ftp_subfolder=>'/sub', :protocol=>"test"}
      ]}
      response.should be_success
      @ss.reload
      @ss.should have(2).search_schedules
      email = @ss.search_schedules.find_by_email_addresses('b@example.com')
      email.run_hour.should == 6
      email.day_of_month.should == 1
      email.download_format.should == 'xls'
      email.run_monday?.should be_true
      email.run_tuesday?.should be_false
      email.run_wednesday?.should be_false
      email.run_thursday?.should be_false
      email.run_friday?.should be_false
      email.run_saturday?.should be_false
      email.run_sunday?.should be_false

      ftp = @ss.search_schedules.find_by_ftp_server("ftp.example.com")
      ftp.ftp_username.should == 'user'
      ftp.ftp_password.should == 'pass'
      ftp.ftp_subfolder.should == '/sub'
      ftp.protocol.should == 'test'
    end
    it "should recreate criterions" do
      @ss.search_criterions.create!(:model_field_uid=>:prod_uid,:operator=>:sw,:value=>'X')
      put :update, :id=>@ss.id, :search_setup=>{:search_criterions=>[
        {:mfid=>'prod_uid',:operator=>'eq',:value=>'y',:label=>'XX',:datatype=>'string',:include_empty=>true},
        {:mfid=>'prod_name',:operator=>'ew',:value=>'q',:label=>'XX',:datatype=>'string',:include_empty=>false}
      ]}
      response.should be_success
      @ss.reload
      @ss.should have(2).search_criterions
      @ss.search_criterions.find_by_model_field_uid_and_operator_and_value('prod_uid','eq','y').include_empty?.should be_true
      @ss.search_criterions.find_by_model_field_uid_and_operator_and_value('prod_name','ew','q').include_empty?.should be_false
    end
  end

  describe :last_search_id do
    it "should get last search based on search_run" do
      ss_first = Factory(:search_setup,:user=>@user)
      ss_second = Factory(:search_setup,:user=>@user)
      ss_first.touch
      get :last_search_id
      JSON.parse(response.body)['id'].should == ss_first.id.to_s
    end
    
    it "should return last search updated if no search_runs" do
      ss_first = Factory(:search_setup,:user=>@user,updated_at:1.day.ago)
      ss_second = Factory(:search_setup,:user=>@user,updated_at:1.year.ago)
      get :last_search_id
      JSON.parse(response.body)['id'].should == ss_first.id.to_s
    end
   
    it "should return 0 if no search setups" do
      get :last_search_id
      JSON.parse(response.body)['id'].should == "0"
    end
    it "should not find a search for another user" do
      ss_first = Factory(:search_setup)
      ss_second = Factory(:search_setup,:user=>@user)
      ss_first.touch
      get :last_search_id
      JSON.parse(response.body)['id'].should == ss_second.id.to_s
    end
  end

  describe :setup do
    it 'should redirect for html' do
      get :setup, :id=>1
      response.should redirect_to '/advanced_search#/1'
    end
    it "should write response for json" do
      @ss = Factory(:search_setup,:user=>@user,:name=>'MYNAME',
        :include_links=>true,:no_time=>true,:module_type=>"Product")
      @ss.search_columns.create!(:rank=>1,:model_field_uid=>:prod_uid)
      @ss.search_columns.create!(:rank=>2,:model_field_uid=>:prod_name)
      @ss.sort_criterions.create!(:rank=>1,:model_field_uid=>:prod_uid,:descending=>true)
      @ss.search_criterions.create!(:model_field_uid=>:prod_name,:operator=>:eq,:value=>"123")
      # Include ftp information to make sure we're not actually including it by default for non-admin users
      @ss.search_schedules.create!(:email_addresses=>'x@example.com',:run_monday=>true,:run_hour=>8,:download_format=>:xls,:day_of_month=>11, :ftp_server=>"server", :ftp_username=>"user", :ftp_password=>"password", :ftp_subfolder=>"subf", :protocol=>"protocol")
      get :setup, :id=>@ss.id, :format=>'json'
      response.should be_success
      h = JSON.parse response.body
      h['id'].should == @ss.id
      h['name'].should == @ss.name
      h['include_links'].should be_true
      h['no_time'].should be_true
      h['allow_ftp'].should be_false
      h['user']['email'].should == @user.email
      h['module_type'].should == @ss.module_type
      search_list = h['search_list']
      search_list.should have(1).search
      search_list.first['name'].should == @ss.name
      search_list.first['id'].should == @ss.id
      search_list.first['module'].should == "Product"
      h['search_columns'].should == [
        {"mfid"=>"prod_uid","label"=>ModelField.find_by_uid(:prod_uid).label,"rank"=>1},
        {"mfid"=>"prod_name","label"=>ModelField.find_by_uid(:prod_name).label,"rank"=>2}
      ]
      h['sort_criterions'].should == [
        {"mfid"=>"prod_uid","descending"=>true,"label"=>ModelField.find_by_uid(:prod_uid).label,"rank"=>1}
      ]
      h['search_criterions'].should == [
        {"mfid"=>"prod_name","operator"=>"eq","label"=>ModelField.find_by_uid(:prod_name).label,"value"=>"123","datatype"=>"string","include_empty"=>false}
      ]
      h['search_schedules'].should == [
        {"email_addresses"=>"x@example.com","run_monday"=>true,"run_tuesday"=>false,"run_wednesday"=>false,"run_thursday"=>false,
          "run_friday"=>false,"run_saturday"=>false,"run_sunday"=>false,"run_hour"=>8,
          "download_format"=>"xls","day_of_month"=>11}
      ]
      expected_model_fields = ModelField.sort_by_label(CoreModule::PRODUCT.model_fields_including_children.values).collect {|mf|
        x = {}
        x['mfid'] = mf.uid.to_s
        x['label'] = mf.label
        x['datatype'] = mf.data_type.to_s
        x
      }
      h['model_fields'].should == expected_model_fields
    end
    it "should write response for json and include ftp information for admins" do
      @ss = Factory(:search_setup,:user=>@user,:name=>'MYNAME',
        :include_links=>true,:no_time=>true,:module_type=>"Product")
      @ss.search_columns.create!(:rank=>1,:model_field_uid=>:prod_uid)
      @ss.search_columns.create!(:rank=>2,:model_field_uid=>:prod_name)
      @ss.sort_criterions.create!(:rank=>1,:model_field_uid=>:prod_uid,:descending=>true)
      @ss.search_criterions.create!(:model_field_uid=>:prod_name,:operator=>:eq,:value=>"123")
      @ss.search_schedules.create!(:email_addresses=>'x@example.com',:run_monday=>true,:run_hour=>8,:download_format=>:xls,:day_of_month=>11, 
                                  :ftp_server=>"server", :ftp_username=>"user", :ftp_password=>"password", :ftp_subfolder=>"subf", :protocol=>"protocol")
      SearchSetup.any_instance.stub(:can_ftp?).and_return true

      get :setup, :id=>@ss.id, :format=>'json'
      response.should be_success
      h = JSON.parse response.body
      h['allow_ftp'].should be_true
      h['search_schedules'].should == [
        {"email_addresses"=>"x@example.com","run_monday"=>true,"run_tuesday"=>false,"run_wednesday"=>false,"run_thursday"=>false,
          "run_friday"=>false,"run_saturday"=>false,"run_sunday"=>false,"run_hour"=>8,
          "download_format"=>"xls","day_of_month"=>11, "ftp_server"=>"server", "ftp_username"=>"user", "ftp_password"=>"password", "ftp_subfolder"=>"subf", "protocol"=>"protocol"}
      ]
    end
    it "should set include empty for criterions" do
      @ss = Factory(:search_setup,:user=>@user,:name=>'MYNAME',
        :module_type=>"Product")
      @ss.search_criterions.create!(:model_field_uid=>:prod_name,:operator=>:eq,:value=>"123",:include_empty=>true)
      get :setup, :id=>@ss.id, :format=>'json'
      response.should be_success
      h = JSON.parse response.body
      h['search_criterions'][0]['include_empty'].should be_true
    end
    it "should 404 if not for correct user" do
      ss = Factory(:search_setup)
      lambda {get :show, :id=>ss.id, :format=>:json}.should raise_error ActionController::RoutingError 
    end
    it "should set allow ftp to true for admin" do
      ss = Factory(:search_setup,:user=>@user)
      SearchSetup.any_instance.should_receive(:can_ftp?).and_return(true)
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      h['allow_ftp'].should be_true
    end
    it "should return full search list for current module_type" do
      ss = Factory(:search_setup,:user=>@user,:name=>"B",:module_type=>"Order")
      ss2 = Factory(:search_setup,:user=>@user,:name=>"A",:module_type=>"Order")
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      list = h['search_list']
      list.should have(2).results
      list.collect {|ss| ss['id']}.should == [ss2.id,ss.id]
    end
    it "should not return search list for different module_types" do
      ss = Factory(:search_setup,:user=>@user,:name=>"B",:module_type=>"Order")
      ss2 = Factory(:search_setup,:user=>@user,:name=>"A",:module_type=>"Order")
      dont_find = Factory(:search_setup,:user=>@user,:module_type=>"Product")
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      list = h['search_list']
      list.should have(2).results
      list.collect {|ss| ss['id']}.should == [ss2.id,ss.id]
    end
    it "should not show model fields that user cannot view" do
      ss = Factory(:search_setup,:user=>@user,:module_type=>'Entry')
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      found_duty_due = false
      h['model_fields'].each {|mf| found_duty_due = true if mf['mfid']=='ent_duty_due_date'}
      found_duty_due.should be_false
    end
  end

  describe :show do
    it 'should redirect for html' do
      get :show, :id=>1
      response.should redirect_to '/advanced_search#/1'
    end
    it "should write page and per page to search run" do
      @ss = Factory(:search_setup,:user=>@user)
      get :show, :id=>@ss.id, :page=>'2', :per_page=>'40', :format=>'json'
      response.should be_success
      @ss.reload
      sr = @ss.search_runs.first
      sr.page.should == 2
      sr.per_page.should == 40
    end
    context :json do
      before :each do
        @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
        @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
        @ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>2)
        @p = Factory(:product,:name=>'mpn')
        User.any_instance.stub(:edit_classifications?).and_return(true) #to allow bulk actions
        SearchQuery.any_instance.stub(:count).and_return(501)
        SearchQuery.any_instance.stub(:unique_parent_count).and_return(42)
        Product.any_instance.stub(:can_view?).and_return(true)
      end
      it "should render json response" do
        Product.any_instance.stub(:can_edit?).and_return(true)
        User.any_instance.stub(:edit_classifications?).and_return(true) #to allow bulk actions
        SearchQuery.any_instance.stub(:count).and_return(501)
        SearchQuery.any_instance.stub(:unique_parent_count).and_return(42)
        Product.any_instance.stub(:can_view?).and_return(true)
        Product.any_instance.stub(:can_edit?).and_return(true)
        get :show, :id=>@ss.id, :page=>'1', :per_page=>'50', :format=>'json'
        response.should be_success
        r = JSON.parse response.body
        r['id'].should == @ss.id
        r['search_run_id'].should == @ss.search_runs.first.id
        r['name'].should == @ss.name
        r['page'].should == 1
        r['total_pages'].should == 11
        r['total_objects'].should == 42
        r['columns'].should == [ModelField.find_by_uid(:prod_uid).label,ModelField.find_by_uid(:prod_name).label]
        r['rows'].should == [
          { 'id'=>@p.id,
            'links'=>
              [ {'label'=>'View','url'=>"/products/#{@p.id}"},
                {'label'=>'Edit','url'=>"/products/#{@p.id}/edit"}
              ],
            'vals'=>
              [@p.unique_identifier,@p.name]}]
        expected_bulk_actions = []
        CoreModule::PRODUCT.bulk_actions(@user).each do |k,v|
          h = {"label"=>k.to_s}
          if v.is_a? String
            h["path"] = eval(v)
          else
            h["path"] = v[:path]
            h["callback"] = v[:ajax_callback]
          end
          expected_bulk_actions << h
        end
        r['bulk_actions'].should == expected_bulk_actions 
      end
      it "should 404 if not for current_user" do
        u = Factory(:user)
        @ss.update_attributes(:user_id=>u.id)
        lambda {get :show, :id=>@ss.id, :page=>'1', :per_page=>'50', :format=>'json'}.should raise_error ActionController::RoutingError
      end
      it "should default page to 1" do
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        r['page'].should == 1
      end
      it "should default per_page to 100" do
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        r['total_pages'].should == 6
      end
      it "should set per_page to 10 for IE < 9" do
        @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        r['total_pages'].should == 51
      end
      it 'should render second page' do
        p2 = Factory(:product,:name=>'prod2')
        get :show, :id=>@ss.id, :format=>'json', :per_page=>'1', :page=>'2'
        r = JSON.parse response.body
        r['page'].should == 2
        r['rows'].first['id'].should == p2.id
      end
      it "shouldn't write edit link if user cannot edit" do
        Product.any_instance.stub(:can_edit?).and_return(false)
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        links = r['rows'].first['links']
        links.should have(1).link
        links.first['label'].should == 'View'
      end
      it 'should accept per_page parameter' do
        get :show, :id=>@ss.id, :per_page=>'10', :format=>'json'
        r = JSON.parse response.body
        r['total_pages'].should == 51
      end
      it "should not utilize per_page parameter if it's value is greater than default per page value" do
        get :show, :id=>@ss.id, :per_page=>'200', :format=>'json'
        r = JSON.parse response.body
        r['total_pages'].should == 6
      end
    end
  end
  describe :download do
    before :each do
      @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
      @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
      @ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>2)
      @ss.search_criterions.create!(:model_field_uid=>:prod_uid,:operator=>:sw,:value=>'X')
      @p = Factory(:product,:name=>'mpn')
      Product.any_instance.stub(:can_view?).and_return(true)
    end
    it "should run file for XLS" do
      wb = mock('wb')
      wb.should_receive(:write)
      XlsMaker.any_instance.should_receive(:make_from_search_query).with(instance_of(SearchQuery), per_page: 100).and_return(wb)
      get :download, :id=>@ss.id, :format=>:xls
      response.should be_success
      response.headers['Content-Type'].should == "application/vnd.ms-excel"
      response.headers['Content-Disposition'].should == "attachment; filename=\"#{@ss.name}.xls\""
    end
    context :delayed_job do
      before :each do
        @dj_status = Delayed::Worker.delay_jobs
        Delayed::Worker.delay_jobs = false
      end
      after :each do
        Delayed::Worker.delay_jobs = @dj_status
      end
      it "should delay running file for json" do
        ReportResult.should_receive(:run_report!).with(@ss.name, @user, 'OpenChain::Report::XLSSearch', :settings=>{ 'search_setup_id'=>@ss.id })
        get :download, :id=>@ss.id, :format=>:json
        response.should be_success
        JSON.parse(response.body)['ok'].should == 'ok'
      end
      it "should call delay" do
        ReportResult.should_receive(:run_report!).with(@ss.name,instance_of(User),'OpenChain::Report::XLSSearch',{:settings=>{'search_setup_id'=>@ss.id}})
        get :download, :id=>@ss.id, :format=>:json
        response.should be_success
        JSON.parse(response.body)['ok'].should == 'ok'
      end
      it "errors if search is not downloadable" do
        SearchSetup.any_instance.should_receive(:downloadable?) do |errors|
          errors << "This is an error"
          false
        end
        get :download, :id=>@ss.id, :format=>:json
        response.should be_error
        JSON.parse(response.body)['errors'].should == ["This is an error"]
      end
    end
    it "should 404 if user doesn't own search setup" do
      ss = Factory(:search_setup)
      lambda {get :download, :id=>ss.id, :format=>:xls}.should raise_error ActionController::RoutingError 
    end
  end

  describe :legacy_javascripts? do
    it "should not include legacy javascripts" do
      AdvancedSearchController.new.legacy_javascripts?.should be_false
    end
  end
end
