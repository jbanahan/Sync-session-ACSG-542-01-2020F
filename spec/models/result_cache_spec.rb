require 'spec_helper'

describe ResultCache do
  before :each do
    Product.stub(:search_where).and_return("1=1")
  end
  describe :next do
    it "should find in cache" do
      ResultCache.new(:object_ids=>[7,1,5].to_json).next(1).should == 5
    end
    it "should find in next page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      6.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>3,:object_ids=>[p[0],p[1],p[2]].to_json)
      rc.next(p[2]).should == p[3]
    end
    it "should return nil if end of results" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      2.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>2,:object_ids=>[p[0],p[1]].to_json)
      rc.next(p[1]).should be_nil
    end
    it "should return nil if not in cache" do
      ResultCache.new(:object_ids=>[7,1,5].to_json).next(4).should be_nil
    end
    it "should not return same object id from next page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>1)
      p1 = Factory(:product)
      p2 = Factory(:product)
      5.times do |i| 
        Factory(:classification,:product=>p1)
        Factory(:classification,:product=>p2)
      end
      rc = ResultCache.new(:result_cacheable=>ss,:page=>1,:per_page=>2,:object_ids=>[p1.id].to_json)
      rc.next(p1.id).should==p2.id
      rc.page.should == 3
    end
  end
  describe :previous do
    it "should find in cache" do
      ResultCache.new(:object_ids=>[7,1,5].to_json).previous(5).should == 1
    end
    it "should find in previous page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      p = []
      6.times {|i| p << Factory(:product,:unique_identifier=>"rc#{i}").id }
      rc = ResultCache.new(:result_cacheable=>ss,:page=>2,:per_page=>3,:object_ids=>[p[3],p[4],p[5]].to_json)
      rc.previous(p[3]).should == p[2]
    end
    it "should return nil if beginning of results" do
      ResultCache.new(:object_ids=>[7,1,5].to_json,:page=>1).previous(7).should be_nil
    end
    it "should return nil if not in cache" do
      ResultCache.new(:object_ids=>[7,1,5].to_json,:page=>1).previous(4).should be_nil
    end
    it "should not return same object id from previous page" do
      ss = Factory(:search_setup,:module_type=>"Product")
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)
      ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>1)
      p1 = Factory(:product)
      p2 = Factory(:product)
      5.times do |i| 
        Factory(:classification,:product=>p1)
        Factory(:classification,:product=>p2)
      end
      rc = ResultCache.new(:result_cacheable=>ss,:page=>5,:per_page=>2,:object_ids=>[p2.id].to_json)
      rc.previous(p2.id).should == p1.id
      rc.page.should == 3
    end
  end
end
