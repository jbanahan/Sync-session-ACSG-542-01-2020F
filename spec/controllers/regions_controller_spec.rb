describe RegionsController do
  describe "security" do
    let(:user) { create(:user) }
    let(:region) { create(:region) }
    let(:country) { create(:country) }

    before do
      sign_in_as user
    end

    it "restricts index" do
      get :index
      expect(response).to redirect_to request.referer
    end

    it "restricts create" do
      post :create, name: "EMEA", format: :json
      expect(Region.find_by(name: "EMEA")).to be_nil
      expect(response).to redirect_to request.referer
    end

    it "restricts destroy" do
      r = create(:region, name: "EMEA")
      delete :destroy, id: r.id
      expect(Region.find_by(name: "EMEA")).not_to be_nil
      expect(response).to redirect_to request.referer
    end

    it "restricts add country" do
      get :add_country, id: region.id, country_id: country.id
      region.reload
      expect(region.countries.to_a).to be_empty
      expect(response).to redirect_to request.referer
    end

    it "restricts remove country" do
      region.countries << country
      get :remove_country, id: region.id, country_id: country.id
      region.reload
      expect(region.countries.to_a).to eq([country])
      expect(response).to redirect_to request.referer
    end
  end

  context "security passed" do
    let(:user) { create(:admin_user) }
    let!(:region) { create(:region) }

    before do
      sign_in_as user
    end

    describe "index" do
      it "shows all regions" do
        r2 = create(:region)
        get :index
        expect(response).to be_success
        expect(assigns(:regions).to_a).to eq([region, r2])
      end
    end

    describe "create" do
      it "makes new region" do
        post :create, 'region' => {'name' => "EMEA"}, :format => :json
        expect(response).to redirect_to regions_path
      end
    end

    describe "destroy" do
      it "removes region" do
        id = region.id
        delete :destroy, id: id
        expect(response).to redirect_to regions_path
        expect(Region.find_by(id: id)).to be_nil
      end
    end

    context "country management" do
      let(:country) { create(:country) }

      describe "add_country" do
        it "adds country to region" do
          get :add_country, id: region.id, country_id: country.id
          expect(response).to redirect_to regions_path
          region.reload
          expect(region.countries.to_a).to eq([country])
        end
      end

      describe "remove_country" do
        it "removes country from region" do
          region.countries << country
          get :remove_country, id: region.id, country_id: country.id
          expect(response).to redirect_to regions_path
          region.reload
          expect(region.countries.to_a).to eq([])
        end
      end
    end
  end
end
