require 'spec_helper'

describe OpenChain::CustomHandler::DasProductGenerator do
  #YYYYMMDDHHMMSSLLL-DAPART.DAT
  describe :remote_file_name do
    it "should be in correct format" do
      described_class.new.remote_file_name.should match /[0-9]{17}-DAPART\.DAT/
    end
  end

  describe :generate do
    it "should create xls file, and ftp it" do
      h = described_class.new
      h.should_receive(:sync_xls).and_return('x')
      h.should_receive(:ftp_file).with('x').and_return('y')
      h.generate.should eq 'y'
    end
  end

  describe :ftp_credentials do
    it "should send credentials" do
      described_class.new.ftp_credentials.should == {server: 'ftp2.vandegriftinc.com', username: "VFITRACK", password: 'RL2VFftp', folder: 'to_ecs/DAS/products'}
    end
  end

  describe :auto_confirm? do
    it "should not autoconfirm" do
      described_class.new.auto_confirm?.should be_false
    end
  end

  describe :query do
    before :each do
      @us = Factory(:country, iso_code: 'US')
      @classification = Factory(:classification, :country_id=>@us.id)
      @tariff_record = Factory(:tariff_record, :classification => @classification, :hts_1 => '12345')
      @match_product = @classification.product
      @barthco_cust = Factory(:custom_definition,:id=>1,:module_type=>'Product',:label=>'Barthco Customer ID')
      @test_style = Factory(:custom_definition,:module_type=>'Product',:label=>'Test Style')
      @match_product.update_custom_value! @barthco_cust, '100'
    end

    it "should not return products that don't need sync" do
      dont_find = Factory(:classification, country_id: @us.id).product
      dont_find.update_custom_value! @barthco_cust, '100' #my guess is barthco is not relevant to DAS...
      dont_find.sync_records.create!(trading_partner: described_class::SYNC_CODE, sent_at: 1.minute.ago, confirmed_at: 1.second.ago)
      dont_find.update_attributes(updated_at: 1.day.ago)
      r = Product.connection.execute described_class.new.query
      r.count.should == 1
      r.first[1].should == @match_product.unique_identifier
    end
  end

  describe :fixed_position_map do
    it "should return mapping" do
      described_class.new.fixed_position_map.should == [
        {:len=>15}, #unique identifier
        {:len=>40}, #name
        {:len=>6}, #unit cost
        {:len=>2}, #country of origin
        {:len=>10} #hts
      ]
    end
  end
end
