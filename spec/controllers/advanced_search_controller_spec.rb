require 'spec_helper'

describe AdvancedSearchController do
  before :each do
    @user = Factory(:master_user)
    activate_authlogic
    UserSession.create! @user
  end

  describe :show do
    it 'should redirect for html' do
      get :show, :id=>1
      response.should redirect_to '/advanced_search#/1'
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
        r['search_run_id'].should == @ss.search_run.id
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
    end
  end
end
