require 'spec_helper'

describe OpenChain::ModelFieldDefinition::EntryFieldDefinition do
  describe 'ent_first_billed_date' do
    let :mf do
      ModelField.find_by_uid :ent_first_billed_date
    end
    it "should be first billed date when multiple bills" do
      bi = Factory(:broker_invoice,invoice_date:Date.new(2016,10,1))
      Factory(:broker_invoice,invoice_date:Date.new(2016,10,2),entry:bi.entry)

      ss = SearchSetup.new(module_type:'Entry',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_first_billed_date',operator:'eq',value:'2016-10-01')
      expect(ss.result_keys).to eq [bi.entry.id]

      # test in memory export value
      expect(mf.process_export(bi.entry,nil,true)).to eq Date.new(2016,10,1)
    end
    it "should be nil when no bills" do
      ent = Factory(:entry)

      ss = SearchSetup.new(module_type:'Entry',user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_first_billed_date',operator:'null')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent,nil,true)).to be_nil
    end
    it "should be read only" do
      expect(mf.read_only?).to be_truthy
    end
  end
end
