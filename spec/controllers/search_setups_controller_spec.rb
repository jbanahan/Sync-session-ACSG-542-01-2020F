describe SearchSetupsController do
  let!(:master_setup) { stub_master_setup }

  before(:each) do
    @u = FactoryBot(:user, :time_zone=>"Hawaii")

    sign_in_as @u
    @ss = SearchSetup.create!(:name=>"Test", :user=>@u, :module_type=>'Entry')
    # release date is used becuase it's a datetime
    @crit1 = @ss.search_criterions.create!(:model_field_uid=>'ent_release_date', :operator=>"eq", :value=>"2013-01-01")
    # export date is used because it's a date (not a date time)
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
      expect(response).to redirect_to('/products')

      # make sure the release date value had the time zone appended to it
      @ss.reload
      expect(@ss.search_criterions.first.value).to eq("2013-01-01" + " " + @u.time_zone)
      expect(@ss.search_criterions.first.include_empty).to be_truthy
      expect(@ss.search_criterions.second.value).to eq("2013-01-01")
      expect(@ss.search_criterions.second.include_empty).to be_nil
    end
    it 'should not fail if no search criterions are in the search' do
      post :update,
      {"search_setup"=>{"name"=>"New Name", "download_format"=>"xls", "include_links"=>"0", "no_time"=>"0", "module_type"=>"Product"}, \
        "id"=>"#{@ss.id}"}

      expect(response).to redirect_to('/products')
      @ss = SearchSetup.find(@ss.id)
      expect(@ss.search_criterions.length).to eq(2)
    end
  end
  describe 'give' do
    it "should give and redirect" do
      u2 = FactoryBot(:user, :company=>@u.company)
      get :give, :id=>@ss.id, :other_user_id=>u2.id
      expect(response).to redirect_to '/entries'
      expect(u2.search_setups.first.name).to eq("Test (From #{@u.full_name})")
    end
    it "should give and return ok for json" do
      u2 = FactoryBot(:user, :company=>@u.company)
      post :give, :id=>@ss.id, :other_user_id=>u2.id, :format=>:json
      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r["ok"]).not_to be_nil
      expect(r["given_to"]).to eq(u2.full_name)
    end
    it "should 404 if search not found" do
      u2 = FactoryBot(:user, :company=>@u.company)
      expect {post :give, :id=>(@ss.id+1), :other_user_id=>u2.id}.to raise_error ActionController::RoutingError
      expect(SearchSetup.count).to eq(1)
    end
    it "should error if user cannot give report to other user" do
      u2 = FactoryBot(:user)
      post :give, :id=>@ss.id, :other_user_id=>u2.id, :format=>:json
      expect(response.status).to eq(422)
      r = JSON.parse(response.body)
      expect(r["error"]).to eq("You do not have permission to give this search to user with ID #{u2.id}.")
    end
  end

  describe 'copy' do
    before do
      request.accept = "application/json"
    end

    it "should make a copy of the search for the user, skipping 'locked' flag" do
      @ss.update locked: true
      post :copy, id: @ss.id

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r["ok"]).not_to be_nil
      copy = SearchSetup.where(id: r["id"]).first
      expect(copy).not_to be_nil
      expect(r["name"]).to eq("Copy of #{@ss.name}")
      expect(copy.locked?).to be_falsey
    end

    it "automatically locks any report copied by Integration User" do
      u = User.integration
      sign_in_as u
      @ss.update locked: true, user: u
      post :copy, id: @ss.id

      expect(response).to be_success
      r = JSON.parse(response.body)
      copy = SearchSetup.where(id: r["id"]).first
      expect(copy.locked?).to eq true
    end

    it "should accept copy name from requst" do
      post :copy, id: @ss.id, new_name: "New Name"

      expect(response).to be_success
      r = JSON.parse(response.body)
      expect(r["ok"]).not_to be_nil
      expect(SearchSetup.where(name: "New Name").first).not_to be_nil
      expect(r["name"]).to eq("New Name")
    end

    it "should not allow creating duplicate search names" do
      post :copy, id: @ss.id, new_name: @ss.name

      expect(response.status).to eq(422)
      r = JSON.parse(response.body)
      expect(r["error"]).to eq("A search with the name '#{@ss.name}' already exists.  Please use a different name or rename the existing report.")
    end
  end
end
