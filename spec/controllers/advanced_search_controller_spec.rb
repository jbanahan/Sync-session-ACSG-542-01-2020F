describe AdvancedSearchController do
  before :each do
    @user = Factory(:master_user,:email=>'a@example.com')

    sign_in_as @user
  end

  describe "destroy" do
    it "should destroy and return id of previous search" do
      old_search = Factory(:search_setup,:module_type=>'Product',:user=>@user)
      new_search = Factory(:search_setup,:module_type=>'Product',:user=>@user)
      delete :destroy, :id=>new_search.id
      expect(JSON.parse(response.body)['id']).to eq(old_search.id)
      expect(SearchSetup.find_by_id(new_search.id)).to be_nil
    end
    it "should destroy and create new search if none found" do
      ss = Factory(:search_setup,:user=>@user)
      delete :destroy, :id=>ss.id
      id = JSON.parse(response.body)['id']
      new_ss = SearchSetup.find(id)
      expect(new_ss.user).to eq(@user)
      expect(new_ss.module_type).to eq(ss.module_type)
    end
    it "should not allow destroy of another users search (404)" do
      ss = Factory(:search_setup)
      expect {delete :destroy, :id=>ss.id}.to raise_error ActionController::RoutingError
      expect(SearchSetup.find_by_id(ss.id)).not_to be_nil
    end
  end
  describe "create" do
    before :each do
      allow(CoreModule::PRODUCT).to receive(:enabled?).and_return(true)
      allow(CoreModule::PRODUCT).to receive(:view?).and_return(true)
    end
    it "should create new default search" do
      post :create, :module_type=>"Product"
      expect(response).to be_success
      h = JSON.parse response.body
      ss = SearchSetup.find h['id']
      expect(ss.user).to eq(@user)
      expect(ss.module_type).to eq('Product')
      expect(ss.name).to eq("New Search")
    end
    it "should fail if user cannot view module" do
      allow(CoreModule::PRODUCT).to receive(:view?).and_return(false)
      expect {post :create, :module_type=>"Product"}.to raise_error ActionController::RoutingError
      expect(SearchSetup.for_user(@user)).to be_empty
    end
    it "should fail if module not specified" do
      expect {post :create}.to raise_error ActionController::RoutingError
      expect(SearchSetup.for_user(@user)).to be_empty
    end
  end
  describe "update" do
    before :each do
      @ss = Factory(:search_setup,:name=>"X",:user=>@user,:include_links=>true,:no_time=>false,
        :module_type=>"Product")
    end
    it "should 404 for wrong user" do
      ss = Factory(:search_setup)
      expect {put :update, :id=>ss.id, :search_setup=>{:name=>'q'}}.to raise_error ActionController::RoutingError
    end
    it "returns error if sort is submitted without search criterion" do
      put :update, :id=>@ss.id, :search_setup=>{:sort_criterions=>[{:mfid=>'prod_name'}]}
      expect(response).to be_error
      expect(JSON.parse(response.body)['error']).to eq "Must have a search criterion to include sorts or schedules!"
      @ss.reload
      expect(@ss.sort_criterions).to be_empty
    end
    it "returns error if schedule is submitted without search criterion" do
      put :update, :id=>@ss.id, :search_setup=>{:search_schedules=>[{:email_addresses=>'b@example.com'}]}
      expect(response).to be_error
      expect(JSON.parse(response.body)['error']).to eq "Must have a search criterion to include sorts or schedules!"
      @ss.reload
      expect(@ss.search_schedules).to be_empty
    end
    it "returns error if email-address field is too long" do
      addr = "b@#{'z' * 250}.com"
      put :update, :id=>@ss.id, :search_setup=>{:search_criterions=> [{:mfid=>'prod_uid',:operator=>'eq',:value=>'y'}], 
                                                :search_schedules=>[{:email_addresses=>addr}]}
      expect(response).to be_error
      expect(JSON.parse(response.body)['error']).to eq "Email address field must be no more than 255 characters!"
      @ss.reload
      expect(@ss.search_schedules).to be_empty
    end
    it "should update name" do
      put :update, :id=>@ss.id, :search_setup=>{:name=>'Y',:include_links=>false,:no_time=>true}
      expect(response).to be_success
      @ss.reload
      expect(@ss.name).to eq("Y")
      expect(@ss.include_links?).to be_falsey
      expect(@ss.no_time?).to be_truthy
    end
    it "should recreate columns" do
      @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
      put :update, :id=>@ss.id, :search_setup=>{:search_columns=>[{:mfid=>'prod_uid',:label=>"UID",:rank=>2},
        {:mfid=>'prod_name',:rank=>1,:label=>'m'},
        {:mfid=>'_constsomeotherjunk', :label=> 'Broker', :constant_field_value => 'Vandegrift', :rank=> 3}
      ]}
      expect(response).to be_success
      @ss.reload
      expect(@ss.search_columns.size).to eq(3)
      expect(@ss.search_columns.find_by(rank: 1, model_field_uid: 'prod_name')).not_to be_nil
      expect(@ss.search_columns.find_by(rank: 2, model_field_uid: 'prod_uid')).not_to be_nil
      constant_field = @ss.search_columns.find_by(rank: 3, model_field_uid: '_constsomeotherjunk')
      expect(constant_field.constant_field_name).to eq "Broker"
      expect(constant_field.constant_field_value).to eq "Vandegrift"
    end
    it "should recreate sorts" do
      @ss.sort_criterions.create!(:model_field_uid=>:prod_uid,:rank=>1,:descending=>false)
      put :update, :id=>@ss.id, :search_setup=>{:sort_criterions=>[
        {:mfid=>'prod_name',:label=>'NM',:rank=>1,:descending=>true},
        {:mfid=>'prod_uid',:label=>'UID',:rank=>2,:descending=>false}],
        :search_criterions=> [{:mfid=>'prod_uid',:operator=>'eq',:value=>'y'}]}
      expect(response).to be_success
      @ss.reload
      expect(@ss.sort_criterions.size).to eq(2)
      expect(@ss.sort_criterions.find_by(rank: 1, model_field_uid: 'prod_name')).to be_descending
      expect(@ss.sort_criterions.find_by(rank: 2, model_field_uid: 'prod_uid')).not_to be_descending
    end
    it "should recreate schedules" do
      allow_any_instance_of(SearchSetup).to receive(:can_ftp?).and_return(true)
      @ss.search_schedules.create!(:email_addresses=>"a@example.com")
      put :update, :id=>@ss.id, :search_setup=>{:search_schedules=>[
        {:email_addresses=>'b@example.com',:run_hour=>6,:day_of_month=>1,:download_format=>'xls',
          :run_monday=>true,:run_tuesday=>false,:run_wednesday=>false,:run_thursday=>false,:run_friday=>false,:run_saturday=>false,:run_sunday=>false,
          :exclude_file_timestamp=>true, :disabled=>true, :report_failure_count=>2 },
        {:ftp_server=>'ftp.example.com',:ftp_username=>'user',:ftp_password=>'pass',:ftp_subfolder=>'/sub', :protocol=>"test", ftp_port: "123"}
      ], :search_criterions=> [{:mfid=>'prod_uid',:operator=>'eq',:value=>'y'}]}
      expect(response).to be_success
      @ss.reload
      expect(@ss.search_schedules.size).to eq(2)
      email = @ss.search_schedules.find_by(email_addresses: 'b@example.com')
      expect(email.run_hour).to eq(6)
      expect(email.day_of_month).to eq(1)
      expect(email.download_format).to eq('xls')
      expect(email.run_monday?).to be_truthy
      expect(email.run_tuesday?).to be_falsey
      expect(email.run_wednesday?).to be_falsey
      expect(email.run_thursday?).to be_falsey
      expect(email.run_friday?).to be_falsey
      expect(email.run_saturday?).to be_falsey
      expect(email.run_sunday?).to be_falsey
      expect(email.exclude_file_timestamp).to be_truthy
      expect(email.disabled).to be_truthy
      expect(email.report_failure_count).to eq(2)

      ftp = @ss.search_schedules.find_by(ftp_server: "ftp.example.com")
      expect(ftp.ftp_username).to eq('user')
      expect(ftp.ftp_password).to eq('pass')
      expect(ftp.ftp_subfolder).to eq('/sub')
      expect(ftp.protocol).to eq('test')
      expect(ftp.ftp_port).to eq "123"
    end
    it "should recreate criterions" do
      @ss.search_criterions.create!(:model_field_uid=>:prod_uid,:operator=>:sw,:value=>'X')
      put :update, :id=>@ss.id, :search_setup=>{:search_criterions=>[
        {:mfid=>'prod_uid',:operator=>'eq',:value=>'y',:label=>'XX',:datatype=>'string',:include_empty=>true},
        {:mfid=>'prod_name',:operator=>'ew',:value=>'q',:label=>'XX',:datatype=>'string',:include_empty=>false}
      ]}
      expect(response).to be_success
      @ss.reload
      expect(@ss.search_criterions.size).to eq(2)
      expect(@ss.search_criterions.find_by(model_field_uid: "prod_uid", operator: "eq", value: 'y').include_empty?).to be_truthy
      expect(@ss.search_criterions.find_by(model_field_uid: "prod_name", operator: "ew", value: "q").include_empty?).to be_falsey
    end
  end

  describe "last_search_id" do
    it "should get last search based on search_run" do
      ss_first = Factory(:search_setup,:user=>@user)
      ss_second = Factory(:search_setup,:user=>@user)
      ss_first.touch
      get :last_search_id
      expect(JSON.parse(response.body)['id']).to eq(ss_first.id.to_s)
    end

    it "should return last search updated if no search_runs" do
      ss_first = Factory(:search_setup,:user=>@user,updated_at:1.day.ago)
      ss_second = Factory(:search_setup,:user=>@user,updated_at:1.year.ago)
      get :last_search_id
      expect(JSON.parse(response.body)['id']).to eq(ss_first.id.to_s)
    end

    it "should return 0 if no search setups" do
      get :last_search_id
      expect(JSON.parse(response.body)['id']).to eq("0")
    end
    it "should not find a search for another user" do
      ss_first = Factory(:search_setup)
      ss_second = Factory(:search_setup,:user=>@user)
      ss_first.touch
      get :last_search_id
      expect(JSON.parse(response.body)['id']).to eq(ss_second.id.to_s)
    end
  end

  describe "setup" do
    it 'should redirect for html' do
      get :setup, :id=>1
      expect(response).to redirect_to '/advanced_search#/1'
    end
    it "should write response for json" do
      @ss = Factory(:search_setup,:user=>@user,:name=>'MYNAME',
        :include_links=>true,:no_time=>true,:module_type=>"Product")
      @ss.search_columns.create!(:rank=>1,:model_field_uid=>:prod_uid)
      @ss.search_columns.create!(:rank=>2,:model_field_uid=>:prod_name)
      @ss.search_columns.create!(:rank=>3,:model_field_uid=>:_const, constant_field_name: "Broker", constant_field_value: "Vandegrift")
      @ss.sort_criterions.create!(:rank=>1,:model_field_uid=>:prod_uid,:descending=>true)
      @ss.search_criterions.create!(:model_field_uid=>:prod_name,:operator=>:eq,:value=>"123")
      # Include ftp information to make sure we're not actually including it by default for non-admin users
      @ss.search_schedules.create!(:email_addresses=>'x@example.com',:send_if_empty=>true,:run_monday=>true,:run_hour=>8, :exclude_file_timestamp=>true,:download_format=>:xls,:day_of_month=>11, :ftp_server=>"server", :ftp_username=>"user", :ftp_password=>"password", :ftp_subfolder=>"subf", :protocol=>"protocol", :disabled=>"true", :report_failure_count=>2)
      get :setup, :id=>@ss.id, :format=>'json'
      expect(response).to be_success
      h = JSON.parse response.body
      expect(h['id']).to eq(@ss.id)
      expect(h['name']).to eq(@ss.name)
      expect(h['include_links']).to be_truthy
      expect(h['no_time']).to be_truthy
      expect(h['allow_ftp']).to be_falsey
      expect(h['user']['email']).to eq(@user.email)
      expect(h['module_type']).to eq(@ss.module_type)
      expect(h['title']).to eq "Product"
      expect(h['allow_template']).to be_falsey
      search_list = h['search_list']
      expect(search_list.size).to eq(1)
      expect(search_list.first['name']).to eq(@ss.name)
      expect(search_list.first['id']).to eq(@ss.id)
      expect(search_list.first['module']).to eq("Product")
      expect(h['search_columns']).to eq([
        {"mfid"=>"prod_uid","label"=>ModelField.find_by_uid(:prod_uid).label,"rank"=>1, "constant_field_value"=>nil},
        {"mfid"=>"prod_name","label"=>ModelField.find_by_uid(:prod_name).label,"rank"=>2, "constant_field_value"=>nil},
        {"mfid"=>"_const","label"=>"Broker","rank"=>3, "constant_field_value"=>"Vandegrift"}
      ])
      expect(h['sort_criterions']).to eq([
        {"mfid"=>"prod_uid","descending"=>true,"label"=>ModelField.find_by_uid(:prod_uid).label,"rank"=>1}
      ])
      expect(h['search_criterions']).to eq([
        {"mfid"=>"prod_name","operator"=>"eq","label"=>ModelField.find_by_uid(:prod_name).label,"value"=>"123","datatype"=>"string","include_empty"=>false}
      ])
      expect(h['search_schedules']).to eq([
        {"mailing_list_id"=>nil,"email_addresses"=>"x@example.com","send_if_empty"=>true,"run_monday"=>true,"run_tuesday"=>false,"run_wednesday"=>false,"run_thursday"=>false,
          "run_friday"=>false,"run_saturday"=>false,"run_sunday"=>false,"run_hour"=>8,
          "download_format"=>"xls","day_of_month"=>11, "exclude_file_timestamp"=>true, "disabled"=>true, "report_failure_count"=>2}
      ])
      no_non_accessible = CoreModule::PRODUCT.default_module_chain.model_fields.values.collect {|mf| mf.user_accessible? ? mf : nil}.compact
      no_non_accessible.delete_if {|mf| !mf.can_view?(@user)}
      expected_model_fields = ModelField.sort_by_label(no_non_accessible).collect {|mf|
        x = {}
        x['mfid'] = mf.uid.to_s
        x['label'] = mf.label
        x['datatype'] = mf.data_type.to_s
        x
      }
      expect(h['model_fields']).to eq(expected_model_fields)
    end
    it "should write response for json and include ftp information for admins" do
      @ss = Factory(:search_setup,:user=>@user,:name=>'MYNAME',
        :include_links=>true,:no_time=>true,:module_type=>"Product")
      @ss.search_columns.create!(:rank=>1,:model_field_uid=>:prod_uid)
      @ss.search_columns.create!(:rank=>2,:model_field_uid=>:prod_name)
      @ss.sort_criterions.create!(:rank=>1,:model_field_uid=>:prod_uid,:descending=>true)
      @ss.search_criterions.create!(:model_field_uid=>:prod_name,:operator=>:eq,:value=>"123")
      @ss.search_schedules.create!(:email_addresses=>'x@example.com', :send_if_empty=>true,:run_monday=>true,:run_hour=>8,:download_format=>:xls,:day_of_month=>11,:disabled=>"false",:report_failure_count=>2,
                                  :exclude_file_timestamp=>true, :ftp_server=>"server", :ftp_username=>"user", :ftp_password=>"password", :ftp_subfolder=>"subf", :protocol=>"protocol", :ftp_port=>"123")
      allow_any_instance_of(SearchSetup).to receive(:can_ftp?).and_return true

      get :setup, :id=>@ss.id, :format=>'json'
      expect(response).to be_success
      h = JSON.parse response.body
      expect(h['allow_ftp']).to be_truthy
      expect(h['search_schedules']).to eq([
        {"mailing_list_id"=>nil,"email_addresses"=>"x@example.com","send_if_empty"=>true,"run_monday"=>true,"run_tuesday"=>false,"run_wednesday"=>false,"run_thursday"=>false,
          "run_friday"=>false,"run_saturday"=>false,"run_sunday"=>false,"run_hour"=>8,"disabled"=>false,"report_failure_count"=>2,
          "download_format"=>"xls","day_of_month"=>11, "exclude_file_timestamp"=>true, "ftp_server"=>"server", "ftp_username"=>"user", "ftp_password"=>"password", 
          "ftp_subfolder"=>"subf", "protocol"=>"protocol", "ftp_port" => "123"}
      ])
    end
    it "should set include empty for criterions" do
      @ss = Factory(:search_setup,:user=>@user,:name=>'MYNAME',
        :module_type=>"Product")
      @ss.search_criterions.create!(:model_field_uid=>:prod_name,:operator=>:eq,:value=>"123",:include_empty=>true)
      get :setup, :id=>@ss.id, :format=>'json'
      expect(response).to be_success
      h = JSON.parse response.body
      expect(h['search_criterions'][0]['include_empty']).to be_truthy
    end
    it "should 404 if not for correct user" do
      ss = Factory(:search_setup)
      expect {get :show, :id=>ss.id, :format=>:json}.to raise_error ActionController::RoutingError
    end
    it "should set allow ftp to true for admin" do
      ss = Factory(:search_setup,:user=>@user)
      expect_any_instance_of(SearchSetup).to receive(:can_ftp?).and_return(true)
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      expect(h['allow_ftp']).to be_truthy
    end
    it "should return full search list for current module_type" do
      ss = Factory(:search_setup,:user=>@user,:name=>"B",:module_type=>"Order")
      ss2 = Factory(:search_setup,:user=>@user,:name=>"A",:module_type=>"Order")
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      list = h['search_list']
      expect(list.size).to eq(2)
      expect(list.collect {|ss| ss['id']}).to eq([ss2.id,ss.id])
    end
    it "should not return search list for different module_types" do
      ss = Factory(:search_setup,:user=>@user,:name=>"B",:module_type=>"Order")
      ss2 = Factory(:search_setup,:user=>@user,:name=>"A",:module_type=>"Order")
      dont_find = Factory(:search_setup,:user=>@user,:module_type=>"Product")
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      list = h['search_list']
      expect(list.size).to eq(2)
      expect(list.collect {|ss| ss['id']}).to eq([ss2.id,ss.id])
    end
    it "should not show model fields that user cannot view" do
      allow_any_instance_of(ModelField).to receive(:can_view?).with(@user).and_return false
      ss = Factory(:search_setup,:user=>@user,:module_type=>'Entry')
      get :setup, :id=>ss.id, :format=>:json
      h = JSON.parse response.body
      found_duty_due = false
      h['model_fields'].each {|mf| found_duty_due = true if mf['mfid']=='ent_duty_due_date'}
      expect(found_duty_due).to be_falsey
    end
  end

  describe "show" do
    it 'should redirect for html' do
      get :show, :id=>1
      expect(response).to redirect_to '/advanced_search#/1/1'
    end
    it "should write page and per page to search run" do
      @ss = Factory(:search_setup,:user=>@user)
      get :show, :id=>@ss.id, :page=>'2', :per_page=>'40', :format=>'json'
      expect(response).to be_success
      @ss.reload
      sr = @ss.search_runs.first
      expect(sr.page).to eq(2)
      expect(sr.per_page).to eq(40)
    end
    context "json" do
      before :each do
        @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
        @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
        @ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>2)
        @p = Factory(:product,:name=>'mpn')
        allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) #to allow bulk actions
        allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
        allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
        allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
      end
      it "should render json response" do
        allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
        allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) #to allow bulk actions
        allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
        allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
        allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
        allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
        get :show, :id=>@ss.id, :page=>'1', :per_page=>'50', :format=>'json'
        expect(response).to be_success
        r = JSON.parse response.body
        expect(r['id']).to eq(@ss.id)
        expect(r['search_run_id']).to eq(@ss.search_runs.first.id)
        expect(r['name']).to eq(@ss.name)
        expect(r['page']).to eq(1)
        expect(r['total_pages']).to eq(11)
        expect(r['columns']).to eq([ModelField.find_by_uid(:prod_uid).label,ModelField.find_by_uid(:prod_name).label])
        expect(r['rows']).to eq([
          { 'id'=>@p.id,
            'links'=>
              [ {'label'=>'View','url'=>"/products/#{@p.id}"},
                {'label'=>'Edit','url'=>"/products/#{@p.id}/edit"}
              ],
            'vals'=>
              [@p.unique_identifier,@p.name]}])
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
        expect(r['bulk_actions']).to eq(expected_bulk_actions)
      end
      it "should 404 if not for current_user" do
        u = Factory(:user)
        @ss.update_attributes(:user_id=>u.id)
        expect {get :show, :id=>@ss.id, :page=>'1', :per_page=>'50', :format=>'json'}.to raise_error ActionController::RoutingError
      end
      it "should default page to 1" do
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        expect(r['page']).to eq(1)
      end
      it "should default per_page to 100" do
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        expect(r['total_pages']).to eq(6)
      end
      it "should set per_page to 10 for IE < 9" do
        @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        expect(r['total_pages']).to eq(51)
      end
      it 'should render second page' do
        p2 = Factory(:product,:name=>'prod2')
        get :show, :id=>@ss.id, :format=>'json', :per_page=>'1', :page=>'2'
        r = JSON.parse response.body
        expect(r['page']).to eq(2)
        expect(r['rows'].first['id']).to eq(p2.id)
      end
      it "shouldn't write edit link if user cannot edit" do
        allow_any_instance_of(Product).to receive(:can_edit?).and_return(false)
        get :show, :id=>@ss.id, :format=>'json'
        r = JSON.parse response.body
        links = r['rows'].first['links']
        expect(links.size).to eq(1)
        expect(links.first['label']).to eq('View')
      end
      it 'should accept per_page parameter' do
        get :show, :id=>@ss.id, :per_page=>'10', :format=>'json'
        r = JSON.parse response.body
        expect(r['total_pages']).to eq(51)
      end
      it "should not utilize per_page parameter if it's value is greater than default per page value" do
        get :show, :id=>@ss.id, :per_page=>'200', :format=>'json'
        r = JSON.parse response.body
        expect(r['total_pages']).to eq(6)
      end
    end
  end
  describe "download" do
    let (:tempfile) { 
      Tempfile.new ["report", "test"]
    }

    before :each do
      @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
      @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
      @ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>2)
      @ss.search_criterions.create!(:model_field_uid=>:prod_uid,:operator=>:sw,:value=>'X')
      @p = Factory(:product,:name=>'mpn')
      allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
    end

    after :each do 
      tempfile.close! unless tempfile.closed?
    end

    [{format: "xls", mime_type: "application/vnd.ms-excel"}, {format: "csv", mime_type: "text/csv"}, {format: "xlsx", mime_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}].each do |params|
      it "downloads #{params[:format]} files" do
        expect(SearchWriter).to receive(:write_search) do |search_setup, io, opts|
          expect(search_setup).to eq @ss
          expect(io).to be_a(StringIO)
          expect(io.external_encoding.name).to eq "ASCII-8BIT"
          expect(opts[:user]).to eq @user
          expect(opts[:output_format]).to eq params[:format]
          expect(opts[:max_results]).to eq 100
          nil
        end

        expect(SearchSchedule).to receive(:report_name).with(@ss, params[:format], include_timestamp: true).and_return "report_name.#{params[:format]}"
        get :download, :id=>@ss.id, :format=>params[:format].to_sym
        expect(response).to be_success
        expect(response.headers['Content-Type']).to eq(params[:mime_type])
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=\"report_name.#{params[:format]}\"")
      end
    end

    context "delayed_job", :disable_delayed_jobs do
      it "should delay running file for json" do
        expect(ReportResult).to receive(:run_report!).with(@ss.name, @user, 'OpenChain::Report::AsyncSearch', :settings=>{ 'search_setup_id'=>@ss.id })
        get :download, :id=>@ss.id, :format=>:json
        expect(response).to be_success
        expect(JSON.parse(response.body)['ok']).to eq('ok')
      end
      it "should call delay" do
        expect(ReportResult).to receive(:run_report!).with(@ss.name,instance_of(User),'OpenChain::Report::AsyncSearch',{:settings=>{'search_setup_id'=>@ss.id}})
        get :download, :id=>@ss.id, :format=>:json
        expect(response).to be_success
        expect(JSON.parse(response.body)['ok']).to eq('ok')
      end
      it "errors if search is not downloadable" do
        expect_any_instance_of(SearchSetup).to receive(:downloadable?) do |instance, errors|
          errors << "This is an error"
          false
        end
        get :download, :id=>@ss.id, :format=>:json
        expect(response).to be_error
        expect(JSON.parse(response.body)['errors']).to eq(["This is an error"])
      end
    end
    it "should 404 if user doesn't own search setup" do
      ss = Factory(:search_setup)
      expect {get :download, :id=>ss.id, :format=>:xls}.to raise_error ActionController::RoutingError
    end
  end

  describe "send_email" do
    before(:each) do
      @ss = Factory(:search_setup,:name=>"X",:user=>@user,:include_links=>true,:no_time=>false,
        :module_type=>"Product")
      allow_any_instance_of(SearchSetup).to receive(:downloadable?).and_return true
    end

    it "handles mailing lists" do
      sender = "tufnel@stonehenge.biz"
      recipient = "st-hubbins@hellhole.co.uk, smalls@sharksandwich.net"
      mail_subject = "amp"
      body = "Goes to 11."
      mailing_list = "1"

      d = double("delay")
      expect(OpenChain::Report::AsyncSearch).to receive(:delay).and_return d
      expect(d).to receive(:run_and_email_report).with(@user.id, @ss.id, {'to' => recipient, 'reply_to' => sender, 'subject' => mail_subject, 'body' => body, 'mailing_list' => mailing_list})
      post :send_email, :id=>@ss.id, :mail_fields => {:to => recipient, :reply_to => sender, :subject => mail_subject, :body => body, :mailing_list => mailing_list }
      expect(JSON.parse(response.body)).to eq({'ok' => 'ok'})
    end

    it "runs report as a delayed job" do
      sender = "tufnel@stonehenge.biz"
      recipient = "st-hubbins@hellhole.co.uk, smalls@sharksandwich.net"
      mail_subject = "amp"
      body = "Goes to 11."

      d = double("delay")
      expect(OpenChain::Report::AsyncSearch).to receive(:delay).and_return d
      expect(d).to receive(:run_and_email_report).with(@user.id, @ss.id, {'to' => recipient, 'reply_to' => sender, 'subject' => mail_subject, 'body' => body})
      post :send_email, :id=>@ss.id, :mail_fields => {:to => recipient, :reply_to => sender, :subject => mail_subject, :body => body}
      expect(JSON.parse(response.body)).to eq({'ok' => 'ok'})
    end

    it "errors if email missing" do
      expect(OpenChain::Report::AsyncSearch).not_to receive(:delay)

      post :send_email, :id=>@ss.id, :mail_fields=> {}
      expect(JSON.parse(response.body)['error']).to eq "Please enter an email address."
    end

    it "errors if one or more emails aren't valid" do
      expect(OpenChain::Report::AsyncSearch).not_to receive(:delay)

      post :send_email, :id=>@ss.id, :mail_fields=> {'to' => 'tufnel@stonehenge.biz, st-hubbins.com'}
      expect(JSON.parse(response.body)['error']).to eq "Please ensure all email addresses are valid and separated by commas."
    end

    it "errors if there are more than 10 email addresses" do
      expect(OpenChain::Report::AsyncSearch).not_to receive(:delay)

      email_list = Array.new(11){|i| "address#{i}@vandegriftinc.com"}.join(', ')
      post :send_email, :id=>@ss.id, :mail_fields=> {'to' => email_list}
      expect(JSON.parse(response.body)['error']).to eq "Cannot accept more than 10 email addresses."
    end

    it "errors if search not found" do
      expect { get :send_email, :id=>1000 }.to raise_error("Not Found")
      expect(OpenChain::Report::AsyncSearch).not_to receive(:delay)
    end

    it "errors if search isn't downloadable" do
      expect_any_instance_of(SearchSetup).to receive(:downloadable?) do |instance, errors|
          errors << "This is an error"
          false
        end
      get :send_email, :id=>@ss.id
      expect(OpenChain::Report::AsyncSearch).not_to receive(:delay)
      expect(response).to be_error
      expect(JSON.parse(response.body)['error']).to eq "This is an error"
    end
  end

  describe "legacy_javascripts?" do
    it "should not include legacy javascripts" do
      expect(AdvancedSearchController.new.legacy_javascripts?).to be_falsey
    end
  end

  context "audit" do
    let(:ss) { Factory(:search_setup, user: @user, name: "search name") }
    
    describe "show_audit" do
      
      it "renders if called with search setup that belongs to user" do
        ra1 = RandomAudit.create! user: @user, search_setup: ss, report_date: Date.new(2018,3,15)
        ra2 = RandomAudit.create! user: @user, search_setup: ss, report_date: Date.new(2018,3,16)
        ra3 = RandomAudit.create! user: Factory(:user), search_setup: ss, report_date: Date.new(2018,3,17)
        get :show_audit, id: ss.id
        expect(response).to render_template :show_audit
        expect(assigns(:ss_id)).to eq ss.id
        expect(assigns(:audits)).to eq [ra2, ra1]
      end

      it "redirects otherwise" do
        ss.update_attributes user: Factory(:user)
        get :show_audit, id: ss.id
        expect(response).to be_redirect
      end
    end

    describe "audit", :disable_delayed_jobs do
      before { expect_any_instance_of(SearchSetup).to receive(:downloadable?).and_return true }
      
      it "runs report if search setup belongs to user and necessary fields are populated" do
        expect(ReportResult).to receive(:run_report!).with("search name (Random Audit)", @user, 'OpenChain::Report::AsyncSearch', settings: {'search_setup_id' => ss.id, 'audit' => {percent: 25, record_type: 'header'}})
        post :audit, id: ss.id, percent: 25, record_type: "header"
        expect(flash[:notices]).to eq ["Your report has been scheduled. You'll receive a system message when it finishes."]
      end

      it "redirects if search setup doesn't belong to user" do
        ss.update_attributes user: Factory(:user)
        expect(ReportResult).to_not receive(:run_report!)
        post :audit, id: ss.id, percent: 25, record_type: "header"
        expect(response).to be_redirect
        expect(flash[:errors]).to eq ["You don't have access to this search."]
      end

      it "redirects if audit percentage isn't between 1 and 99" do
        expect(ReportResult).to_not receive(:run_report!)
        post :audit, id: ss.id, percent: 125, record_type: "header"
        expect(response).to be_redirect
        expect(flash[:errors]).to eq ["Please enter a percentage between 1 and 99."]
      end

      it "redirects if record type isn't specified" do
        expect(ReportResult).to_not receive(:run_report!)
        post :audit, id: ss.id, percent: 25, record_type: nil
        expect(response).to be_redirect
        expect(flash[:errors]).to eq ["Please select a record type."]
      end
    end
  end
end
