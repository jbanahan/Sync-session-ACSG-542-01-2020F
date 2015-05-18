require 'spec_helper'

describe OpenChain::ModelFieldDefinition::OfficialTariffFieldDefinition do
  describe "WTO 6 Digit" do
    it "should get 6 digit HTS w/o formatting" do
      ot = Factory(:official_tariff,hts_code:'1234567890')
      Factory(:official_tariff,hts_code:'0987654321') #don't find w/ search

      mf = ModelField.find_by_uid(:ot_wto6)
      expect(mf).to be_read_only
      expect(mf.process_export(ot,nil,true)).to eq '123456'

      ss = SearchSetup.new(module_type:'OfficialTariff',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ot_wto6',operator:'eq',value:'123456')
      expect(ss.result_keys).to eq [ot.id]
    end
  end
end