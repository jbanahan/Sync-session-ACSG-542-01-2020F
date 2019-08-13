describe ResultCache do
  before :each do
    allow(Product).to receive(:search_where).and_return("1=1")
  end
  describe "next" do
    it "should load cache if empty" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      2.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>5)
      expect(rc.next(p[0])).to eq(p[1])
    end
    it "should find in cache" do
      expect(ResultCache.new(:object_ids=>[7,1,5].to_json).next(1)).to eq(5)
    end
    it "should find in next page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      6.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>3,:object_ids=>[p[0],p[1],p[2]].to_json)
      expect(rc.next(p[2])).to eq(p[3])
    end
    it "should return nil if end of results" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      2.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>2,:object_ids=>[p[0],p[1]].to_json)
      expect(rc.next(p[1])).to be_nil
    end
    it "should return nil if not in cache" do
      rc = ResultCache.new(:object_ids=>[7,1,5].to_json)
      allow(rc).to receive(:load_current_page)
      expect(rc.next(4)).to be_nil
    end
    it "should not return same object id from next page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>1)
      p1 = Factory(:product, unique_identifier: "1")
      p2 = Factory(:product, unique_identifier: "2")
      3.times do |i| 
        Factory(:classification,:product=>p1) 
      end
      Factory(:classification,:product=>p2)
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>2,:object_ids=>[p1.id].to_json)
      expect(rc.next(p1.id)).to eq(p2.id)
      expect(rc.page).to eq(2)
    end
  end
  describe "previous" do
    it "should find in cache" do
      expect(ResultCache.new(:object_ids=>[7,1,5].to_json).previous(5)).to eq(1)
    end
    it "should load cache if empty" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      2.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>5)
      expect(rc.previous(p[1])).to eq(p[0])
    end
    it "should find in previous page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      6.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>2,:per_page=>3,:object_ids=>[p[3],p[4],p[5]].to_json)
      expect(rc.previous(p[3])).to eq(p[2])
    end
    it "should return nil if beginning of results" do
      expect(ResultCache.new(:object_ids=>[7,1,5].to_json,:page=>1).previous(7)).to be_nil
    end
    it "should return nil if not in cache" do
      rc = ResultCache.new(:object_ids=>[7,1,5].to_json,:page=>1)
      allow(rc).to receive(:load_current_page)
      expect(rc.previous(4)).to be_nil
    end
    it "should not return same object id from previous page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>1)
      p1 = Factory(:product)
      Factory(:classification,:product=>p1)
      p2 = Factory(:product)
      3.times do |i| 
        Factory(:classification,:product=>p2)
      end
      rc = ResultCache.new(:result_cacheable=>ss,:page=>2,:per_page=>2,:object_ids=>[p2.id].to_json)
      expect(rc.previous(p2.id)).to eq(p1.id)
      expect(rc.page).to eq(1)
    end
  end
end
