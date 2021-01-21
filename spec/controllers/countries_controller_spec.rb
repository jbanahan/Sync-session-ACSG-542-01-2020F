describe CountriesController do
  let!(:user) { Factory(:user, admin: true) }
  let!(:country) { Factory(:country, iso_code: "UD", name: "Ünderland", quicksearch_show: false) }

  before do
    sign_in_as user
  end

  describe "index" do
    it "shows index" do
      get :index
      expect(response).to be_success
    end
  end

  describe "edit" do
    it "proceeds for admin user" do
      get :edit, id: country.id
      expect(assigns(:country)).to eq country
      expect(response).to be_success
    end

    it "blocks non-admin user" do
      user.update! admin: false
      get :edit, id: country.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "Only administrators can edit countries."
    end
  end

  describe "show" do
    it "redirects to country edit page" do
      get :show, id: country.id
      expect(response).to redirect_to(edit_country_path(country))
    end
  end

  describe "update" do
    it "updates country with new values" do
      post :update, id: country.id, country: { import_location: "true", quicksearch_show: "true",
                                               classification_rank: "13", active_origin: "true",
                                               iso_code: "IG", name: "ISO code and name should be ignored - not updated" }
      country_upd = Country.where(id: country.id).first
      expect(country_upd.iso_code).to eq "UD"
      expect(country_upd.name).to eq "Ünderland"
      expect(country_upd.import_location).to eq true
      expect(country_upd.quicksearch_show).to eq true
      expect(country_upd.classification_rank).to eq 13
      expect(country_upd.active_origin).to eq true
      expect(response).to redirect_to(countries_path)
      expect(flash[:notices]).to include "Ünderland was successfully updated."
      expect(flash[:notices]).to include "Your change to 'View in QuickSearch' will be reflected after the next server restart."
    end

    it "updates country but doesn't change quicksearch show" do
      post :update, id: country.id, country: { import_location: "true", quicksearch_show: "false" }
      country_upd = Country.where(id: country.id).first
      expect(country_upd.import_location).to eq true
      expect(country_upd.quicksearch_show).to eq false
      expect(response).to redirect_to(countries_path)
      expect(flash[:notices]).to include "Ünderland was successfully updated."
      expect(flash[:notices]).not_to include "Your change to 'View in QuickSearch' will be reflected after the next server restart."
    end

    it "handles error in update" do
      allow_any_instance_of(Country).to receive(:update) {|c| c.errors.add(:base, :mysterious_error, message: "Mysterious error")}.and_return false
      post :update, id: country.id, country: { import_location: "true" }
      expect(response).to have_rendered("edit")
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to include "Mysterious error"
    end

    it "blocks non-admin user" do
      user.update! admin: false
      post :update, id: country.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to include "Only administrators can edit countries."
    end
  end

end
