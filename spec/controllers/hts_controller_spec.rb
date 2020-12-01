describe HtsController do

  describe "country" do
    before :each do
      @usa = FactoryBot(:country, "name"=> "United States", iso_code: "US")
      @tariff1 = FactoryBot(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
    end

    it 'should return the correct hash of values' do
      get :country, "iso"=> "US", format: :json
      expect(response).to be_success
      chapters = JSON.parse(response.body)["chapters"].first
      expect(chapters).not_to be_nil
      expect(chapters["num"]).to eq("12")
      expect(chapters["name"]).to eq("123")
      expect(chapters["sub_headings"]).to eq([])
    end
  end

  describe "chapter" do
    before :each do
      @usa = FactoryBot(:country, "name"=> "United States", iso_code: "US")
      @tariff1 = FactoryBot(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
    end

    it 'should return some stuff for the us' do
      get :chapter, "iso"=> "US", chapter: 12
      expect(response).to be_success
      headings = JSON.parse(response.body)["headings"].first
      expect(headings).not_to be_nil
      expect(headings["num"]).to eq("34")
      expect(headings["name"]).to be_nil
    end

  end

  describe "heading" do
    before :each do
      @usa = FactoryBot(:country, "name"=> "United States", iso_code: "US")
      @tariff1 = FactoryBot(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
    end

    it 'should return some stuff for the us' do
      get :heading, "iso"=> "US", heading: 34
      expect(response).to be_success
      subheadings = JSON.parse(response.body)["sub_headings"]
      expect(subheadings).to eq([])
    end
  end

  describe "subscribed_countries" do
    before :each do
      @usa = FactoryBot(:country, "name"=> "United States", iso_code: "US", import_location: true)
      @can = FactoryBot(:country, "name"=> "Canada", iso_code: "CA", import_location: true)
      @vnm = FactoryBot(:country, "name"=> "Vietnam", iso_code: "VN", import_location: true)
      @tariff1 = FactoryBot(:official_tariff, hts_code: "12345", chapter: 123, country: @usa)
      @tariff2 = FactoryBot(:official_tariff, hts_code: "23456", chapter: 234, country: @can)
      @tariff3 = FactoryBot(:official_tariff, hts_code: "34567", chapter: 345, country: @vnm)
      @tariff4 = FactoryBot(:official_tariff, hts_code: "45678", chapter: 456, country: @usa)
    end

    it "should return all countries in your local OfficialTariff table when logged in" do
      u = FactoryBot(:user); sign_in_as u
      get :subscribed_countries
      expect(response).to be_success
      countries = JSON.parse(response.body)["countries"]
      expect(countries).to eq([{"iso"=>"US", "name"=>"United States", "view"=>true}, {"iso"=>"CA", "name"=>"Canada", "view"=>true}, {"iso"=>"VN", "name"=>"Vietnam", "view"=>true}])
    end

    it "should return all countries available when logged out" do
      get :subscribed_countries
      expect(response).to be_success
      countries = JSON.parse(response.body)["countries"]
      expect(countries).to eq(
        [
          {"iso"=>'US', "name"=>'United States', "view"=>true}, {"iso"=>'CA', "name"=>'Canada', "view"=>true}, {"iso"=>'AU', "name"=>'Australia'}, {"iso"=>'CL', "name"=>'Chile'}, {"iso"=>'CN', "name"=>'China'}, {"iso"=>'HK', "name"=>'Hong Kong'},
          {"iso"=>'ID', "name"=>'Indonesia'}, {"iso"=>'IT', "name"=>'Italy'}, {"iso"=>'JP', "name"=>'Japan'}, {"iso"=>'KR', "name"=>'Korea, Republic of'}, {"iso"=>'MO', "name"=>'Macao'}, {"iso"=>'MY', "name"=>'Malaysia'},
          {"iso"=>'MX', "name"=>'Mexico'}, {"iso"=>'NZ', "name"=>'New Zealand'}, {"iso"=>'NO', "name"=>'Norway'}, {"iso"=>'PE', "name"=>'Peru'}, {"iso"=>'PH', "name"=>'Philippines'}, {"iso"=>'RU', "name"=>'Russian Federation'},
          {"iso"=>'SG', "name"=>'Singapore'}, {"iso"=>'TW', "name"=>'Taiwan'}, {"iso"=>'TH', "name"=>'Thailand'}, {"iso"=>'TR', "name"=>'Turkey'}, {"iso"=>'VN', "name"=>'Vietnam'}
        ]
      )
    end
  end
end
