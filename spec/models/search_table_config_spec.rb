describe SearchTableConfig do
  describe '#for_user' do
    it 'should find generic' do
      u = FactoryBot(:user)
      generic = FactoryBot(:search_table_config, page_uid:'abc')
      for_me = FactoryBot(:search_table_config, page_uid:'abc', user:u)
      for_company = FactoryBot(:search_table_config, page_uid:'abc', company:u.company)

      # don't find these
      FactoryBot(:search_table_config, page_uid:'other')
      FactoryBot(:search_table_config, page_uid:'abc', user:FactoryBot(:user))
      FactoryBot(:search_table_config, page_uid:'abc', company:FactoryBot(:company))
      expect(SearchTableConfig.for_user(u, 'abc').to_a).to eq [generic, for_me, for_company]
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
