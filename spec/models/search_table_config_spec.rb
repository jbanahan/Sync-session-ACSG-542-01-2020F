describe SearchTableConfig do
  describe '#for_user' do
    it 'should find generic' do
      u = Factory(:user)
      generic = Factory(:search_table_config,page_uid:'abc')
      for_me = Factory(:search_table_config,page_uid:'abc',user:u)
      for_company = Factory(:search_table_config,page_uid:'abc',company:u.company)

      # don't find these
      Factory(:search_table_config,page_uid:'other')
      Factory(:search_table_config,page_uid:'abc',user:Factory(:user))
      Factory(:search_table_config,page_uid:'abc',company:Factory(:company))
      expect(SearchTableConfig.for_user(u,'abc').to_a).to eq [generic,for_me,for_company]
    end
  end

  describe '#config_hash' do
    it "should get hash from json" do
      h = {'a'=>'b'}
      expect(SearchTableConfig.new(config_json:'{"a":"b"}').config_hash).to eq h
    end
    it "should return empty hash for nil json" do
      expect(SearchTableConfig.new(config_json:nil).config_hash).to be_empty
    end
  end
  describe '#config_hash=' do
    it "should write hash to json" do
      h = {a:'b'}
      s = SearchTableConfig.new
      s.config_hash = h
      expect(s.config_json).to eq h.to_json
    end
  end
end
