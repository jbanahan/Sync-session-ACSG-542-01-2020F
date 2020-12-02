describe Api::V1::DataCrossReferencesController do
  describe "count_xrefs" do
    let!(:xref_1) { DataCrossReference.create! cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC, key: "KEY", value: "VALUE" }
    let!(:xref_2) { DataCrossReference.create! cross_reference_type: DataCrossReference::US_HTS_TO_CA, key: "KEY2", value: "VALUE2" }
    let!(:u) do
      u = create(:user)
      allow_api_access u
      u
    end

    it "returns number of cross refs for specified type" do
      allow(DataCrossReference).to receive(:can_view?).with("us_hts_to_ca", u).and_return true
      get :count_xrefs, cross_reference_type: "us_hts_to_ca"
      expect(JSON.parse(response.body)["count"]).to eq 1
    end

    it "rejects user without access" do
      allow(DataCrossReference).to receive(:can_view?).with("us_hts_to_ca", u).and_return false
      get :count_xrefs, cross_reference_type: "us_hts_to_ca"
      expect(JSON.parse(response.body)["errors"]).to include "Access denied."
    end
  end
end