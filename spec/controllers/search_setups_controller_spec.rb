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
end
