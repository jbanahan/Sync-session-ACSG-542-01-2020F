describe OfficialTariffsController do
  let!(:us) { Factory(:country, iso_code: "US", import_location: true) }
  let!(:ca) { Factory(:country, iso_code: "CA", import_location: true) }

  before do
    Factory(:official_tariff, hts_code: '1234567890', country: us, remaining_description: 'abc', general_rate: '11', use_count: 5)
    Factory(:official_tariff, hts_code: '1234567899', country: us, remaining_description: 'def', general_rate: 'aa', use_count: 3)
    Factory(:official_tariff, hts_code: '1234567777', country: ca, remaining_description: 'xyz', most_favored_nation_rate: '123', use_count: 6)
  end

  describe "auto_complete" do
    it "returns array of tariffs for given country" do
      get :auto_complete, 'hts' => '1234', 'country' => us.id.to_s, :format => :json
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq(['1234567890', '1234567899'])
    end

    it "provides description if specified" do
      get :auto_complete, 'hts' => '1234', 'country' => us.id.to_s, 'description' => true, :format => :json
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq([{'label' => '1234567890', 'desc' => 'abc'},
                                               {'label' => '1234567899', 'desc' => "def"}])
    end

    context "limits" do
      before do
        25.times do |i|
          Factory(:official_tariff, hts_code: "4455667#{(i + 1).to_s.rjust(3, "0")}", country: us)
        end
      end

      it "limits results to 20 when partial HTS is short" do
        get :auto_complete, 'hts' => '4455667', 'country' => us.id.to_s, :format => :json
        expect(response).to be_success
        # Only 20 of the 25 matches should be returned.
        expect(JSON.parse(response.body)).to eq(['4455667001', '4455667002', '4455667003', '4455667004', '4455667005',
                                                 '4455667006', '4455667007', '4455667008', '4455667009', '4455667010',
                                                 '4455667011', '4455667012', '4455667013', '4455667014', '4455667015',
                                                 '4455667016', '4455667017', '4455667018', '4455667019', '4455667020'])
      end

      it "includes all matching results when partial HTS is short" do
        get :auto_complete, 'hts' => '44556670', 'country' => us.id.to_s, :format => :json
        expect(response).to be_success
        # All 25 matches should be returned.
        expect(JSON.parse(response.body)).to eq(['4455667001', '4455667002', '4455667003', '4455667004', '4455667005',
                                                 '4455667006', '4455667007', '4455667008', '4455667009', '4455667010',
                                                 '4455667011', '4455667012', '4455667013', '4455667014', '4455667015',
                                                 '4455667016', '4455667017', '4455667018', '4455667019', '4455667020',
                                                 '4455667021', '4455667022', '4455667023', '4455667024', '4455667025'])
      end
    end
  end

  describe "auto_classify" do
    it "returns import country classifications" do
      get :auto_classify, 'hts' => '123456789'
      expect(response).to be_success
      body = JSON.parse response.body
      expect(body.size).to eq(2)
      x = body.first
      y = body.last
      expect(x['country_id']).to eq(ca.id)
      expect(y['country_id']).to eq(us.id)
      expect(x['hts']).to eq(
        [{"lacey_act" => false, "code" => "1234567777",
          "desc" => "xyz", "rate" => "123", "use_count" => 6}]
      )
      expect(y['hts']).to eq(
        [{"lacey_act" => false, "code" => "1234567890",
          "desc" => "abc", "rate" => "11", "use_count" => 5},
        {"lacey_act" => false, "code" => "1234567899",
         "desc" => "def", "rate" => "aa", "use_count" => 3}]
      )
    end
  end
end
