require 'spec_helper'

describe Api::V1::VendorsController do
  describe :validate do
    it "runs validations and returns result hash" do
      vend = Factory(:vendor, master: true)
      u = Factory(:user, company: vend)
      allow_api_access u
      bvt = BusinessValidationTemplate.create!(module_type:'Company')
      bvt.search_criterions.create! model_field_uid: "cmp_name", operator: "nq", value: "XXXXXXXXXX"
      
      post :validate, id: vend.id, :format => 'json'
      expect(bvt.business_validation_results.first.validatable).to eq vend
      expect(JSON.parse(response.body)["business_validation_result"]["single_object"]).to eq "Company"
    end
  end
end