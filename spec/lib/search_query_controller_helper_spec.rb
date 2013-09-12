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
      def edit_product_path

      end
    end
  end
  it "should prep hash for response" do
    User.any_instance.stub(:edit_classifications?).and_return(true) #to allow bulk actions
    Product.any_instance.stub(:can_edit?).and_return(true)
    User.any_instance.stub(:edit_classifications?).and_return(true) #to allow bulk actions
    SearchQuery.any_instance.stub(:count).and_return(501)
    SearchQuery.any_instance.stub(:unique_parent_count).and_return(42)
    Product.any_instance.stub(:can_view?).and_return(true)
    Product.any_instance.stub(:can_edit?).and_return(true)
    @user = Factory(:master_user,:email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
    @ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>2)
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>3)
    @p = Factory(:product,:name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss,@user),@user,1,50)
    r = HashWithIndifferentAccess.new r
    r['id'].should == @ss.id
    r['name'].should == @ss.name
    r['page'].should == 1
    r['total_pages'].should == 11
    r['total_objects'].should == 42
    r['columns'].should == [ModelField.find_by_uid(:prod_uid).label,ModelField.find_by_uid(:prod_name).label, ModelField.find_by_uid(:prod_changed_at).label]
    r['rows'].should == [
      { 'id'=>@p.id,
        'links'=>
          [ {'label'=>'View','url'=>"/products/#{@p.id}"},
            {'label'=>'Edit','url'=>"/products/#{@p.id}/edit"}
          ],
        'vals'=>
          [@p.unique_identifier,@p.name, @p.changed_at.in_time_zone(@user.time_zone).to_s]}]
    expected_bulk_actions = []
    CoreModule::PRODUCT.bulk_actions(@user).each do |k,v|
      h = {"label"=>k.to_s}
      if v.is_a? String
        h["path"] = @k.new.send(v)
      else
        h["path"] = v[:path]
        h["callback"] = v[:ajax_callback]
      end
      expected_bulk_actions << h
    end
    r['bulk_actions'].should == expected_bulk_actions 
    r['too_big'].should be_false
  end
  
  it "should set too_big flag when more than 1000 results" do
    User.any_instance.stub(:edit_classifications?).and_return(true) #to allow bulk actions
    Product.any_instance.stub(:can_edit?).and_return(true)
    User.any_instance.stub(:edit_classifications?).and_return(true) #to allow bulk actions
    SearchQuery.any_instance.stub(:count).and_return(1000)
    SearchQuery.any_instance.stub(:unique_parent_count).and_return(42)
    Product.any_instance.stub(:can_view?).and_return(true)
    Product.any_instance.stub(:can_edit?).and_return(true)
    @user = Factory(:master_user,:email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>1)
    @ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>2)
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>3)
    @p = Factory(:product,:name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss,@user),@user,1,50)
    r = HashWithIndifferentAccess.new r
    r['id'].should == @ss.id
    r['too_big'].should be_true
  end

  it "should prep hash for response and hide time when no_time? is true" do
    SearchQuery.any_instance.stub(:count).and_return(501)
    SearchQuery.any_instance.stub(:unique_parent_count).and_return(42)
    Product.any_instance.stub(:can_view?).and_return(true)
    Product.any_instance.stub(:can_edit?).and_return(true)
    @user = Factory(:master_user,:email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>1)
    @ss.no_time= true

    @p = Factory(:product,:name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss,@user),@user,1,50)
    r = HashWithIndifferentAccess.new r
    # The only thing we really care about is how the time was returned
    r['rows'].should == [
      { 'id'=>@p.id,
        'links'=>
          [ {'label'=>'View','url'=>"/products/#{@p.id}"},
            {'label'=>'Edit','url'=>"/products/#{@p.id}/edit"}
          ],
        'vals'=>
          [@p.changed_at.strftime("%Y-%m-%d")]
      }]

  end

  it "should prep hash for response for objects with no 'no_time?' method" do
    SearchQuery.any_instance.stub(:count).and_return(501)
    SearchQuery.any_instance.stub(:unique_parent_count).and_return(42)
    Product.any_instance.stub(:can_view?).and_return(true)
    Product.any_instance.stub(:can_edit?).and_return(true)
    @user = Factory(:master_user,:email=>'a@example.com', :time_zone => "Hawaii")
    @ss = Factory(:search_setup,:user=>@user,:name=>'myname',:module_type=>'Product')
    @ss.search_columns.create!(:model_field_uid=>:prod_changed_at, :rank=>1)

    @ss.should_receive(:respond_to?).with(:search_run).and_return false
    # This ensures that we can run with objects that don't support the no_time? method
    @ss.should_receive(:respond_to?).with(:no_time?).and_return false

    @p = Factory(:product,:name=>'mpn')
    r = @k.new.execute_query_to_hash(SearchQuery.new(@ss,@user),@user,1,50)
    r = HashWithIndifferentAccess.new r
    # The only thing we really care about is how the time was returned
    r['rows'].should == [
      { 'id'=>@p.id,
        'links'=>
          [ {'label'=>'View','url'=>"/products/#{@p.id}"},
            {'label'=>'Edit','url'=>"/products/#{@p.id}/edit"}
          ],
        'vals'=>
          [@p.changed_at.in_time_zone(@user.time_zone).to_s]
      }]
  end
end
