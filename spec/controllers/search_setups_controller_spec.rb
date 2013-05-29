require 'spec_helper'

describe SearchSetupsController do 

  before(:each) do
    @u = Factory(:user, :time_zone=>"Hawaii")
    activate_authlogic
    UserSession.create @u
    @ss = SearchSetup.create!(:name=>"Test", :user=>@u, :module_type=>'Entry')
    #release date is used becuase it's a datetime
    @crit1 = @ss.search_criterions.create!(:model_field_uid=>'ent_release_date', :operator=>"eq", :value=>"2013-01-01")
    #export date is used because it's a date (not a date time)
    @crit2 = @ss.search_criterions.create!(:model_field_uid=>'ent_export_date', :operator=>"eq", :value=>"2013-01-01")
  end

  describe 'update' do
    
    it 'should update a search criterion with datetime for datetime fields' do
      post :update, 
      {"search_setup"=>{"name"=>"New Name", "download_format"=>"xls", "include_links"=>"0", "no_time"=>"0", "module_type"=>"Product", \
          "search_criterions_attributes"=> \
          {"0"=> \
              {"id"=>"#{@crit1.id}", "model_field_uid"=>"ent_release_date", "operator"=>"eq", "value"=>"2013-01-01", "_destroy"=>"false", "include_empty" => true}, \
            "1" => \
              {"id"=>"#{@crit2.id}", "model_field_uid"=>"ent_export_date", "operator"=>"eq", "value"=>"2013-01-01", "_destroy"=>"false"} \
          },
        }, \
      "id"=>"#{@ss.id}"}
      response.should redirect_to('/products')

      #make sure the release date value had the time zone appended to it
      @ss.reload
      @ss.search_criterions.first.value.should == "2013-01-01" + " " + @u.time_zone
      @ss.search_criterions.first.include_empty.should be_true
      @ss.search_criterions.second.value.should == "2013-01-01"
      @ss.search_criterions.second.include_empty.should be_nil
    end
    it 'should not fail if no search criterions are in the search' do 
      post :update, 
      {"search_setup"=>{"name"=>"New Name", "download_format"=>"xls", "include_links"=>"0", "no_time"=>"0", "module_type"=>"Product"}, \
        "id"=>"#{@ss.id}"}
      
      response.should redirect_to('/products')
      @ss = SearchSetup.find(@ss.id)
      @ss.search_criterions.length.should == 2
    end
  end
  describe 'give' do
    it "should give and redirect" do
      u2 = Factory(:user,:company=>@u.company)
      get :give, :id=>@ss.id, :other_user_id=>u2.id
      response.should redirect_to '/entries'
      u2.search_setups.first.name.should == "Test (From #{@u.full_name})" 
    end
    it "should give and return ok for json" do
      u2 = Factory(:user,:company=>@u.company)
      post :give, :id=>@ss.id, :other_user_id=>u2.id, :format=>:json
      response.should be_success
      JSON.parse(response.body)['ok'].should=='ok'
    end
    it "should 404 if search not found" do
      u2 = Factory(:user,:company=>@u.company)
      lambda {post :give, :id=>(@ss.id+1), :other_user_id=>u2.id}.should raise_error ActionController::RoutingError
      SearchSetup.count.should == 1
    end
    it "should error if user cannot give report to other user" do
      u2 = Factory(:user)
      post :give, :id=>@ss.id, :other_user_id=>u2.id, :format=>:json
      response.status.should == 422
    end
  end
end
