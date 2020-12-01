describe OpenChain::SearchQueryControllerHelper do
  before :each do
    @k = Class.new do
      include OpenChain::SearchQueryControllerHelper
      include ActionDispatch::Routing::UrlFor
      include Rails.application.routes.url_helpers
      default_url_options[:host] = 'www.example.com'
      def polymorphic_path o
        "/entries/#{o.id}"
      end
      def edit_polymorphic_path o
        "/entries/#{o.id}/edit"
      end
    end
  end

  describe "execute_query_to_hash" do
    it "should prep hash for response" do
      allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
      allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      @user = FactoryBot(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
      @ss = FactoryBot(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Entry')
      @ss.search_columns.create!(:model_field_uid=>:ent_brok_ref, :rank=>1)
      @ss.search_columns.create!(:model_field_uid=>:ent_entry_num, :rank=>2)
      @ss.search_columns.create!(:model_field_uid=>:ent_import_date, :rank=>3)
      @ss.search_columns.create!(:model_field_uid=>:ent_arrival_date, :rank=>4)
      @p = FactoryBot(:entry, broker_reference: 'XYZ', entry_number: '555', import_date: Date.new(2020, 2, 1), arrival_date: ActiveSupport::TimeZone["America/New_York"].parse("2020-02-02 02:02:02"))
      r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
      r = HashWithIndifferentAccess.new r
      expect(r['id']).to eq(@ss.id)
      expect(r['name']).to eq(@ss.name)
      expect(r['page']).to eq(1)
      expect(r['total_pages']).to eq(11)
      expect(r['columns']).to eq([ModelField.find_by_uid(:ent_brok_ref).label, ModelField.find_by_uid(:ent_entry_num).label, ModelField.find_by_uid(:ent_import_date).label, ModelField.find_by_uid(:ent_arrival_date).label])
      expect(r['rows']).to eq([
        { 'id'=>@p.id,
          'links'=>
            [ {'label'=>'View', 'url'=>"/entries/#{@p.id}"},
              {'label'=>'Edit', 'url'=>"/entries/#{@p.id}/edit"}
            ],
          'vals'=>
            ["XYZ", "555", "2020-02-01", "2020-02-01 21:02"]}])
      expected_bulk_actions = []
      CoreModule::ENTRY.bulk_actions(@user).each do |k, v|
        h = {"label"=>k.to_s}
        if v.is_a? String
          h["path"] = @k.new.send(v)
        else
          h["path"] = v[:path]
          h["callback"] = v[:ajax_callback]
        end
        expected_bulk_actions << h
      end
      expect(r['bulk_actions']).to eq(expected_bulk_actions)
      expect(r['too_big']).to be_falsey
    end

    it "should set too_big flag when more than 1000 results" do
      allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
      allow_any_instance_of(SearchQuery).to receive(:count).and_return(1000)
      allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      @user = FactoryBot(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
      @ss = FactoryBot(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Entry')
      @ss.search_columns.create!(:model_field_uid=>:ent_brok_ref, :rank=>1)
      @ss.search_columns.create!(:model_field_uid=>:ent_entry_num, :rank=>2)
      @ss.search_columns.create!(:model_field_uid=>:ent_import_date, :rank=>3)
      @p = FactoryBot(:entry, :entry_number=>'mpn')
      r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
      r = HashWithIndifferentAccess.new r
      expect(r['id']).to eq(@ss.id)
      expect(r['too_big']).to be_truthy
    end

    it "should prep hash for response and hide time when no_time? is true" do
      allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
      allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      @user = FactoryBot(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
      @ss = FactoryBot(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Entry')
      @ss.search_columns.create!(:model_field_uid=>:ent_arrival_date, :rank=>1)
      @ss.no_time= true

      # Make sure the changed at time is set to a time that will roll back a day
      # based on the timezone translation of GMT -> Hawaii
      @p = FactoryBot(:entry, :entry_number=>'mpn', arrival_date: ActiveSupport::TimeZone["America/New_York"].parse("2020-02-02 02:02:02"))
      r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
      r = HashWithIndifferentAccess.new r
      # The only thing we really care about is how the time was returned
      expect(r['rows']).to eq([
        { 'id'=>@p.id,
          'links'=>
            [ {'label'=>'View', 'url'=>"/entries/#{@p.id}"},
              {'label'=>'Edit', 'url'=>"/entries/#{@p.id}/edit"}
            ],
          'vals'=>
            ['2020-02-01']
        }])
    end

    it "should prep hash for response for objects with no 'no_time?' method" do
      allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
      allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      @user = FactoryBot(:master_user, :email=>'a@example.com', :time_zone => "America/New_York")
      @ss = FactoryBot(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Entry')
      @ss.search_columns.create!(:model_field_uid=>:ent_arrival_date, :rank=>1)

      expect(@ss).to receive(:respond_to?).with(:date_format).and_return true
      expect(@ss).to receive(:respond_to?).with(:search_run).and_return false
      # This ensures that we can run with objects that don't support the no_time? method
      expect(@ss).to receive(:respond_to?).with(:no_time?).and_return false

      @p = FactoryBot(:entry, :entry_number=>'mpn', arrival_date: ActiveSupport::TimeZone["America/New_York"].parse("2020-02-02 02:02:02"))
      r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
      r = HashWithIndifferentAccess.new r
      # The only thing we really care about is how the time was returned
      expect(r['rows']).to eq([
        { 'id'=>@p.id,
          'links'=>
            [ {'label'=>'View', 'url'=>"/entries/#{@p.id}"},
              {'label'=>'Edit', 'url'=>"/entries/#{@p.id}/edit"}
            ],
          'vals'=>
            ["2020-02-02  2:02"]
        }])
    end

    it "should handle object with no date_format method" do
      allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
      allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      @user = FactoryBot(:master_user, :email=>'a@example.com', :time_zone => "America/New_York")
      # Through rspec trickery, this will not respond to date_format.  We're including date_format here to ensure that it's ignored.
      @ss = FactoryBot(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Entry', date_format: "MM/DD/YYYY")
      @ss.search_columns.create!(:model_field_uid=>:ent_arrival_date, :rank=>1)

      expect(@ss).to receive(:respond_to?).with(:date_format).and_return false
      expect(@ss).to receive(:respond_to?).with(:search_run).and_return false
      expect(@ss).to receive(:respond_to?).with(:no_time?).and_return true

      @p = FactoryBot(:entry, :entry_number=>'mpn', arrival_date: ActiveSupport::TimeZone["America/New_York"].parse("2020-02-02 02:02:02"))
      r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
      r = HashWithIndifferentAccess.new r
      # Date should be output in the default format.
      expect(r['rows']).to eq([
        { 'id'=>@p.id,
          'links'=>
            [ {'label'=>'View', 'url'=>"/entries/#{@p.id}"},
              {'label'=>'Edit', 'url'=>"/entries/#{@p.id}/edit"}
            ],
          'vals'=>
            ["2020-02-02  2:02"]
        }])
    end

    it "should prep hash involving a custom date format" do
      allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
      allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return(true)
      allow_any_instance_of(Entry).to receive(:can_edit?).and_return(true)
      @user = FactoryBot(:master_user, :email=>'a@example.com', :time_zone => "America/New_York")
      @ss = FactoryBot(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Entry', date_format: "MM/DD/YYYY")
      @ss.search_columns.create!(:model_field_uid=>:ent_arrival_date, :rank=>1)

      @p = FactoryBot(:entry, :entry_number=>'mpn', arrival_date: ActiveSupport::TimeZone["America/New_York"].parse("2020-02-02 02:02:02"))
      r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
      r = HashWithIndifferentAccess.new r
      expect(r['rows']).to eq([
        { 'id'=>@p.id,
          'links'=>
            [ {'label'=>'View', 'url'=>"/entries/#{@p.id}"},
              {'label'=>'Edit', 'url'=>"/entries/#{@p.id}/edit"}
            ],
          'vals'=>
            ["02/02/2020  2:02"]
        }])
    end
  end

  describe "total_object_count_hash" do
    it "should get total_objects" do
      sq = SearchQuery.new(@ss, @user)
      allow(sq).to receive(:unique_parent_count).and_return(42)
      r = @k.new.total_object_count_hash(sq)
      expect(r['total_objects']).to eq(42)
    end
  end

end
