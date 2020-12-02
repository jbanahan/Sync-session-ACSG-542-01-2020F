describe SpecialTariffCrossReferencesController do
  let(:u) { create(:user, admin: true, sys_admin: true, company: create(:company, master: true)) }

  let(:special_tariff) do
    SpecialTariffCrossReference.create!(hts_number: '1234567890', special_hts_number: '0987654321', country_origin_iso: 'CA',
                                        effective_date_start: Time.zone.now, import_country_iso: 'US', special_tariff_type: '301', suppress_from_feeds: true)
  end

  before do
    sign_in_as u
  end

  describe "GET 'index'" do
    it "is successful" do
      get :index
      expect(response).to be_success
    end

    it "rejects if user isn't admin" do
      u.admin = false
      u.sys_admin = false
      u.save!
      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "GET 'edit'" do
    it "is successful" do
      get :edit, id: special_tariff.id
      expect(response).to be_success
    end

    it "rejects if user isn't an admin" do
      u.sys_admin = false
      u.admin = false
      u.save!

      get :edit, id: special_tariff.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "POST 'update'" do
    let (:updated_attributes) do
      {
        id: special_tariff.id,
        special_tariff_cross_reference: { special_hts_number: '1111111111' }
      }
    end

    it "rejects if user isn't an admin" do
      u.sys_admin = false
      u.admin = false
      u.save!

      post :update, updated_attributes
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end

    it 'updates the special_tariff_cross_reference if user is admin' do
      post :update, updated_attributes
      expect(response).to be_redirect

      special_tariff.reload
      expect(special_tariff.special_hts_number).to eq('1111111111')
      expect(flash[:notices].size).to eq(1)
    end
  end
end
