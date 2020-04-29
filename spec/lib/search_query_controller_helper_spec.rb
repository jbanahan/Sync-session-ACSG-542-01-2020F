describe OpenChain::SearchQueryControllerHelper do
  before :each do
    @k = Class.new do
      include OpenChain::SearchQueryControllerHelper
      include ActionDispatch::Routing::UrlFor
      include Rails.application.routes.url_helpers
      default_url_options[:host] = 'www.example.com'
      def polymorphic_path o
        "/products/#{o.id}"
      end
      def show_bulk_instant_classify_products_path
        "/products/show_bulk_instant_classify"
      end
      def edit_polymorphic_path o
        "/products/#{o.id}/edit"
      end
    end
  end
  it "should prep hash for response" do
    allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
    allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
    allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
    allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
    allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
    allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
    @user = Factory(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_uid, :rank=>1)
    @ss.search_columns.create!(:model_field_uid=>:prod_name, :rank=>2)
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>3)
    @p = Factory(:product, :name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
    r = HashWithIndifferentAccess.new r
    expect(r['id']).to eq(@ss.id)
    expect(r['name']).to eq(@ss.name)
    expect(r['page']).to eq(1)
    expect(r['total_pages']).to eq(11)
    expect(r['columns']).to eq([ModelField.find_by_uid(:prod_uid).label, ModelField.find_by_uid(:prod_name).label, ModelField.find_by_uid(:prod_changed_at).label])
    expect(r['rows']).to eq([
      { 'id'=>@p.id,
        'links'=>
          [ {'label'=>'View', 'url'=>"/products/#{@p.id}"},
            {'label'=>'Edit', 'url'=>"/products/#{@p.id}/edit"}
          ],
        'vals'=>
          [@p.unique_identifier, @p.name, @p.changed_at.in_time_zone(@user.time_zone).to_s]}])
    expected_bulk_actions = []
    CoreModule::PRODUCT.bulk_actions(@user).each do |k, v|
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

  it "should get total_objects" do
    sq = SearchQuery.new(@ss, @user)
    allow(sq).to receive(:unique_parent_count).and_return(42)
    r = @k.new.total_object_count_hash(sq)
    expect(r['total_objects']).to eq(42)
  end

  it "should set too_big flag when more than 1000 results" do
    allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
    allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
    allow_any_instance_of(User).to receive(:edit_classifications?).and_return(true) # to allow bulk actions
    allow_any_instance_of(SearchQuery).to receive(:count).and_return(1000)
    allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
    allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
    allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
    @user = Factory(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_uid, :rank=>1)
    @ss.search_columns.create!(:model_field_uid=>:prod_name, :rank=>2)
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>3)
    @p = Factory(:product, :name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
    r = HashWithIndifferentAccess.new r
    expect(r['id']).to eq(@ss.id)
    expect(r['too_big']).to be_truthy
  end

  it "should prep hash for response and hide time when no_time? is true" do
    allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
    allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
    allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
    allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
    @user = Factory(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>1)
    @ss.no_time= true

    # Make sure the changed at time is set to a time that will roll back a day
    # based on the timezone translation of GMT -> Hawaii
    @p = Factory(:product, :name=>'mpn')
    @p.update_column :changed_at, '2014-02-02'
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
    r = HashWithIndifferentAccess.new r
    # The only thing we really care about is how the time was returned
    expect(r['rows']).to eq([
      { 'id'=>@p.id,
        'links'=>
          [ {'label'=>'View', 'url'=>"/products/#{@p.id}"},
            {'label'=>'Edit', 'url'=>"/products/#{@p.id}/edit"}
          ],
        'vals'=>
          ['2014-02-01']
      }])

  end

  it "should prep hash for response for objects with no 'no_time?' method" do
    allow_any_instance_of(SearchQuery).to receive(:count).and_return(501)
    allow_any_instance_of(SearchQuery).to receive(:unique_parent_count).and_return(42)
    allow_any_instance_of(Product).to receive(:can_view?).and_return(true)
    allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
    @user = Factory(:master_user, :email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup, :user=>@user, :name=>'myname', :module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>1)

    expect(@ss).to receive(:respond_to?).with(:search_run).and_return false
    # This ensures that we can run with objects that don't support the no_time? method
    expect(@ss).to receive(:respond_to?).with(:no_time?).and_return false

    @p = Factory(:product, :name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss, @user), @user, 1, 50)
    r = HashWithIndifferentAccess.new r
    # The only thing we really care about is how the time was returned
    expect(r['rows']).to eq([
      { 'id'=>@p.id,
        'links'=>
          [ {'label'=>'View', 'url'=>"/products/#{@p.id}"},
            {'label'=>'Edit', 'url'=>"/products/#{@p.id}/edit"}
          ],
        'vals'=>
          [@p.changed_at.in_time_zone(@user.time_zone).to_s]
      }])
  end
end
