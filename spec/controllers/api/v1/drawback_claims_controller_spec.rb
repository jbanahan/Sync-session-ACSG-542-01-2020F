require 'spec_helper'

describe Api::V1::DrawbackClaimsController do

  describe :validate do
    it "runs validations and returns result hash" do
      MasterSetup.get.update_attributes(:drawback_enabled=>true)
      u = Factory(:drawback_user, company: Factory(:master_company))
      allow_api_access u
      dc = Factory(:drawback_claim)
      bvt = BusinessValidationTemplate.create!(module_type:'DrawbackClaim')
      bvt.search_criterions.create! model_field_uid: "dc_name", operator: "nq", value: "XXXXXXXXXX"
      
      post :validate, id: dc.id, :format => 'json'
      expect(bvt.business_validation_results.first.validatable).to eq dc
      expect(JSON.parse(response.body)["business_validation_result"]["single_object"]).to eq "DrawbackClaim"
    end
  end
end