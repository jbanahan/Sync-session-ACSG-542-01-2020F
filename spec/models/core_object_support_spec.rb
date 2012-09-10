require 'spec_helper'

describe CoreObjectSupport do
  describe :need_sync do
    before :each do
      @tp = "tradingpartner"
      @p = Factory(:product)
    end
    it "should find products with no sync records" do
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find product with a sync record for a different trading partner" do
      @p.sync_records.create!(:trading_partner=>'other',:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      Product.connection.execute("UPDATE products SET changed_at = NOW() - INTERVAL 1 DAY;")
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products with changed records that haven't been sent" do
      @p.sync_records.create!(:trading_partner=>@tp)
      Product.connection.execute("UPDATE products SET changed_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products sent but not confirmed" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>nil)
      Product.connection.execute("UPDATE products SET changed_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products sent after last confirmation" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>2.minutes.ago)
      Product.connection.execute("UPDATE products SET changed_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products changed after sent" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should not find product where changed_at < sent < confirmed" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      Product.connection.execute("UPDATE products SET changed_at = NOW() - INTERVAL 1 DAY;")
      ns = Product.need_sync @tp
      ns.should be_empty
    end
    it "should not find products based on additional where clauses" do
      dont_find = Factory(:product,:unique_identifier=>"DONTFINDME")
      sc = SearchCriterion.new(:model_field_uid=>'prod_uid',:operator=>'nq',:value=>dont_find.unique_identifier)
      ns = sc.apply Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
  end
  describe :view_url do
    before :each do
      @rh = "x.y.z"
      MasterSetup.get.update_attributes(:request_host=>@rh)
    end
    it "should make url based on request_host" do
      p = Factory(:product)
      p.view_url.should == "http://#{@rh}/products/#{p.id}"
    end
    it "should raise exception if id not set" do
      lambda {Product.new.view_url}.should raise_error
    end
    it "should raise exception if request host not set" do
      MasterSetup.get.update_attributes(:request_host=>nil)
      lambda {Factory(:product).view_url}.should raise_error
    end
  end
  describe :all_attachments do
    it "should sort by attachment type then attached file name then id" do
      p = Factory(:product)
      third = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      second = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      first = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"Q")
      fourth = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      r = p.all_attachments
      r[0].should == first
      r[1].should == second
      r[2].should == third
      r[3].should == fourth
    end
  end
end
