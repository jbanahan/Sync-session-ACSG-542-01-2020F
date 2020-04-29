describe OpenChain::ModelFieldGenerator::CommentGenerator do
  describe '_comment_count' do
    before :each do
      @u = Factory(:admin_user, order_view:true)
      @mf = ModelField.find_by_uid :ord_comment_count
      @ss = SearchSetup.new(name:'Test', user:@u, module_type:'Order')
      @sc = @ss.search_criterions.build(model_field_uid:'ord_comment_count', operator:'eq')
      @ss.search_columns.build(model_field_uid:'ord_comment_count', rank:1)
    end
    it "should work when no comments" do
      o = Factory(:order)
      expect(@mf.process_export(o, nil, true)).to eq 0

      @sc.value = 0
      expected_result = [{row_key:o.id, result:[0]}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
    it "should work when multiple comments" do
      o = Factory(:order)
      2.times {|i| o.comments.create!(body:'x', user:@u)}
      expect(@mf.process_export(o, nil, true)).to eq 2

      @sc.value = 2
      expected_result = [{row_key:o.id, result:[2]}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
  end
  describe '_last_comment_body' do
    before :each do
      @u = Factory(:admin_user, order_view:true)
      @mf = ModelField.find_by_uid :ord_last_comment_body
      @ss = SearchSetup.new(name:'Test', user:@u, module_type:'Order')
      @sc = @ss.search_criterions.build(model_field_uid:'ord_last_comment_body', operator:'eq')
      @ss.search_columns.build(model_field_uid:'ord_last_comment_body', rank:1)
    end
    it "should work when no comments" do
      o = Factory(:order)
      expect(@mf.process_export(o, nil, true)).to eq ''

      @sc.value = ''
      expected_result = [{row_key:o.id, result:['']}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
    it "should work when multiple comments" do
      o = Factory(:order)
      2.times {|i| o.comments.create!(body:i.to_s, user:@u)}
      expect(@mf.process_export(o, nil, true)).to eq '1'

      @sc.value = '1'
      expected_result = [{row_key:o.id, result:['1']}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
  end
  describe '_last_comment_subject' do
    before :each do
      @u = Factory(:admin_user, order_view:true)
      @mf = ModelField.find_by_uid :ord_last_comment_subject
      @ss = SearchSetup.new(name:'Test', user:@u, module_type:'Order')
      @sc = @ss.search_criterions.build(model_field_uid:'ord_last_comment_subject', operator:'eq')
      @ss.search_columns.build(model_field_uid:'ord_last_comment_subject', rank:1)
    end
    it "should work when no comments" do
      o = Factory(:order)
      expect(@mf.process_export(o, nil, true)).to eq ''

      @sc.value = ''
      expected_result = [{row_key:o.id, result:['']}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
    it "should work when multiple comments" do
      o = Factory(:order)
      2.times {|i| o.comments.create!(body:i.to_s, subject: "s#{i}", user:@u)}
      expect(@mf.process_export(o, nil, true)).to eq 's1'

      @sc.value = 's1'
      expected_result = [{row_key:o.id, result:['s1']}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
  end
  describe '_last_comment_by' do
    before :each do
      @u = Factory(:admin_user, order_view:true)
      @mf = ModelField.find_by_uid :ord_last_comment_by
      @ss = SearchSetup.new(name:'Test', user:@u, module_type:'Order')
      @sc = @ss.search_criterions.build(model_field_uid:'ord_last_comment_by', operator:'eq')
      @ss.search_columns.build(model_field_uid:'ord_last_comment_by', rank:1)
    end
    it "should work when no comments" do
      o = Factory(:order)
      expect(@mf.process_export(o, nil, true)).to eq ''

      @sc.value = ''
      expected_result = [{row_key:o.id, result:['']}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
    it "should work when multiple comments" do
      o = Factory(:order)
      2.times {|i| o.comments.create!(body:i.to_s, user:@u)}
      expect(@mf.process_export(o, nil, true)).to eq @u.username

      @sc.value = @u.username
      expected_result = [{row_key:o.id, result:[@u.username]}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
  end
  describe '_last_comment_at' do
    before :each do
      @u = Factory(:admin_user, order_view:true)
      @mf = ModelField.find_by_uid :ord_last_comment_at
      @ss = SearchSetup.new(name:'Test', user:@u, module_type:'Order')
      @sc = @ss.search_criterions.build(model_field_uid:'ord_last_comment_at', operator:'gt')
      @ss.search_columns.build(model_field_uid:'ord_last_comment_at', rank:1)
    end
    it "should work when no comments" do
      o = Factory(:order)
      expect(@mf.process_export(o, nil, true)).to be_nil

      @sc.operator = 'null'
      expected_result = [{row_key:o.id, result:['']}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
    it "should work when multiple comments" do
      o = Factory(:order)
      o.comments.create!(body:"1", user:@u, created_at: 1.minute.ago)
      comment2 = o.comments.create!(body:"2", user:@u)
      comment2.reload
      expect(@mf.process_export(o, nil, true)).to eq comment2.created_at

      @sc.value = 1.day.ago
      expected_result = [{row_key:o.id, result:[comment2.created_at.strftime('%Y-%m-%d %H:%M:%S')]}]
      expect(SearchQuery.new(@ss, @u).execute).to eq expected_result
    end
  end
end