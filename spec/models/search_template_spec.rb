require 'spec_helper'

describe SearchTemplate do
  before :each do
    @ss = SearchSetup.new(name:'MyName',module_type:'Order',include_links:true,no_time:true)
    @ss.search_columns.build(model_field_uid:'ord_ord_num',rank:1)
    @ss.search_columns.build(model_field_uid:'ord_ord_date',rank:2)
    @ss.search_criterions.build(model_field_uid:'ord_ord_num',operator:'sw',value:'X')
    @ss.sort_criterions.build(model_field_uid:'ord_ord_date',descending:true,rank:1)
  end
  describe "create_from_search_setup!" do
    it "should create search template" do
      st = described_class.create_from_search_setup! @ss
      expect(st.name).to eq 'MyName'
      expect(st.module_type).to eq 'Order'
      expect(st.id).to_not be_blank

      expected_hash = {
        'name'=>'MyName','module_type'=>'Order','include_links'=>true,'no_time'=>true,
        'search_columns'=>[
          {'model_field_uid'=>'ord_ord_num','rank'=>1},
          {'model_field_uid'=>'ord_ord_date','rank'=>2}
        ],
        'search_criterions'=>[
          {'model_field_uid'=>'ord_ord_num','operator'=>'sw','value'=>'X'}
        ],
        'sort_criterions'=>[
          {'model_field_uid'=>'ord_ord_date','descending'=>true,'rank'=>1}
        ]
      }
      expect(JSON.parse(st.search_json)).to eq expected_hash
    end
  end

  describe "add_to_user!" do
    it "should create search in user account" do
      st = described_class.create_from_search_setup! @ss
      u = Factory(:user)
      setup = st.add_to_user! u
      setup = SearchSetup.find setup.id
      expect(setup.user).to eq u
      expect(setup.name).to eq @ss.name
      expect(setup.module_type).to eq @ss.module_type
      expect(setup.include_links?).to eq @ss.include_links?
      expect(setup.no_time?).to eq @ss.no_time?

      expect(setup.search_columns.size).to eq 2
      expect(setup.search_columns.first.model_field_uid).to eq 'ord_ord_num'
      expect(setup.search_columns.first.rank).to eq 1
    end
  end

  context 'validations' do
    it "should not allow duplicate template names" do
      st = SearchTemplate.create!(name:'X',search_json:"{'a':'b'}")
      expect {SearchTemplate.create!(name:'X')}.to raise_error /Name has already been taken/
    end
    it "should require name" do
      expect {SearchTemplate.create!(search_json:"{'a':'b'}")}.to raise_error /Name/
    end
    it "should require json" do
      expect {SearchTemplate.create!(name:"x")}.to raise_error /Search json/
    end
  end
end
