describe Api::V1::PortsController do
  before :each do
    @u = FactoryBot(:user)
    allow_api_access @u
  end
  describe "autocomplete" do
    it "should paginate" do
      11.times {|i| FactoryBot(:port, name: "Name #{i}")}
      get :autocomplete, n: "Name"
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 10
    end
    it "returns nothing if no search is entered" do
      11.times {|i| FactoryBot(:port, name: "Name #{i}")}
      get :autocomplete, n: " "
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 0
    end
    it "should allow name filter" do
      p = FactoryBot(:port, name:'XabX')
      p2 = FactoryBot(:port, name:'XdeX')
      get :autocomplete, n: 'ab'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq "(#{p.schedule_k_code}) XabX"
      expect(j.first['id']).to eq p.id
    end

    it "searches on schedule d" do
      p = FactoryBot(:port, name:'XabX', schedule_d_code: "1234", schedule_k_code: "")

      get :autocomplete, n: '12'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq "(#{p.schedule_d_code}) XabX"
    end

    it "searches on schedule K" do
      p = FactoryBot(:port, name:'XabX', schedule_d_code: "", schedule_k_code: "12345")

      get :autocomplete, n: '12'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq "(#{p.schedule_k_code}) XabX"
    end

    it "searches on locode" do
      p = FactoryBot(:port, name:'XabX', schedule_d_code: "", schedule_k_code: "", unlocode: "LOCOD")

      get :autocomplete, n: 'cod'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq "(#{p.unlocode}) XabX"
    end

    it "searches on cbsa port" do
      p = FactoryBot(:port, name:'XabX', schedule_d_code: "", schedule_k_code: "", cbsa_port: "1234")

      get :autocomplete, n: '12'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq "(#{p.cbsa_port}) XabX"
    end

    it "searches on iata code" do
      p = FactoryBot(:port, name:'XabX', schedule_d_code: "", schedule_k_code: "", cbsa_port: "", iata_code: "IAT")

      get :autocomplete, n: 'T'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j.size).to eq 1
      expect(j.first['name']).to eq "(IAT) XabX"
    end
  end
end