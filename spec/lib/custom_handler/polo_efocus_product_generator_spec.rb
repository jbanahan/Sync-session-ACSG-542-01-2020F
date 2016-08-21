require 'spec_helper'

describe OpenChain::CustomHandler::PoloEfocusProductGenerator do
  describe :generate do
    it "should create xls file, and ftp it while rows are written to spreadsheet" do
      h = described_class.new
      expect(h).to receive(:row_count).exactly(3).times.and_return(1, 1, 0)
      expect(h).to receive(:sync_xls).exactly(3).times.and_return('x', 'y', nil)

      expect(h).to receive(:ftp_file).with('x')
      expect(h).to receive(:ftp_file).with('y')

      h.generate
    end
  end
  describe :ftp_credentials do
    it "should send credentials" do
      expect(described_class.new.ftp_credentials).to eq({:username=>'VFITRACK',:password=>'RL2VFftp',:server=>'ftp2.vandegriftinc.com',:folder=>'to_ecs/Ralph_Lauren/efocus_products'})
    end
  end
  describe :auto_confirm? do
    it "should not autoconfirm" do
      expect(described_class.new.auto_confirm?).to be_falsey
    end
  end
  describe :query do
    before :each do
      @us = Factory(:country,:iso_code=>'US')
    end
    it "should use custom where clause" do
      c = described_class.new(:where=>'WHERE 1=2')
      qry = c.query
      expect(qry).to include "WHERE 1=2"
    end
    context "simple tests" do
      before :each do
        # We can instantiate a new efocus product generator here which will create the custom defs we require..then just look them up by label
        @g = described_class.new

        @classification = Factory(:classification, :country_id=>@us.id)
        @tariff_record = Factory(:tariff_record, :classification => @classification, :hts_1 => '12345')
        @match_product = @classification.product
        @barthco_cust = CustomDefinition.where(label: "Barthco Customer ID").first
        @test_style = CustomDefinition.where(label: "Test Style").first
        @set_type = CustomDefinition.where(label: "Set Type").first

        @match_product.update_custom_value! @barthco_cust, '100'
      end
      it 'should not return product without US classification' do
        dont_find = Factory(:classification).product
        dont_find.update_custom_value! @barthco_cust, '100'
        r = Product.connection.execute @g.query
        expect(r.count).to eq(1)
        expect(r.first[6]).to eq(@match_product.unique_identifier)
      end
      it 'should not return multiple rows for multiple country classifications' do
        other_country_class = Factory(:classification,:product=>@match_product)
        r = Product.connection.execute @g.query
        expect(r.count).to eq(1)
        expect(r.first[6]).to eq(@match_product.unique_identifier)
      end
      it "should not return products that don't need sync" do
        dont_find = Factory(:classification,:country_id=>@us.id).product
        dont_find.update_custom_value! @barthco_cust, '100'
        dont_find.sync_records.create!(:trading_partner=>described_class::SYNC_CODE,:sent_at=>1.minute.ago,:confirmed_at=>1.second.ago)
        dont_find.update_attributes(:updated_at=>1.day.ago)
        r = Product.connection.execute @g.query
        expect(r.count).to eq(1)
        expect(r.first[6]).to eq(@match_product.unique_identifier)
      end
      it "should not return products without barthco customer ids" do
        @match_product.custom_values.destroy_all
        r = Product.connection.execute @g.query
        expect(r.count).to eq(0)
      end
      it "should not return products that are test styles" do
        @match_product.update_custom_value! @test_style, 'x'
        r = Product.connection.execute @g.query
        expect(r.count).to eq(0)
      end
      it "should not return products that are non-RL sets and are missing hts numbers" do
        @tariff_record.update_attributes :hts_1 => ''
        r = Product.connection.execute @g.query
        expect(r.count).to eq(0)
      end
      it "should return products that only have hts 2" do
        @tariff_record.update_attributes :hts_1 => '', :hts_2 => "1234"
        r = Product.connection.execute @g.query
        expect(r.count).to eq(1)
        expect(r.first[6]).to eq(@match_product.unique_identifier)
      end
      it "should return products that only have hts 3" do
        @tariff_record.update_attributes :hts_1 => '', :hts_3 => "1234"
        r = Product.connection.execute @g.query
        expect(r.count).to eq(1)
        expect(r.first[6]).to eq(@match_product.unique_identifier)
      end
      it "should return products that are RL sets and are missing hts numbers" do
        @tariff_record.update_attributes :hts_1 => '', :hts_2 => '', :hts_3 => ''
        @classification.update_custom_value! @set_type, 'RL'
        r = Product.connection.execute @g.query
        expect(r.count).to eq(1)
        expect(r.first[6]).to eq(@match_product.unique_identifier)
      end
    end
  end

  describe "run_schedulable" do
    it "runs repeatedly until all products are synced" do
      # New call creates the custom fields (easiest way to do this)
      described_class.new
      us = Factory(:country,:iso_code=>'US')
      barthco_cust = CustomDefinition.where(label: "Barthco Customer ID").first

      product = Factory(:tariff_record, hts_1: "12345", classification: Factory(:classification, country_id: us.id)).product
      product.update_custom_value! barthco_cust, '100'

      product2 = Factory(:tariff_record, hts_1: '12345', classification: Factory(:classification, country_id: us.id)).product
      product2.update_custom_value! barthco_cust, '100'

      product3 = Factory(:tariff_record, hts_1: '12345', classification: Factory(:classification, country_id: us.id)).product
      product3.update_custom_value! barthco_cust, '100'

      allow_any_instance_of(described_class).to receive(:max_results).and_return 1
      expect_any_instance_of(described_class).to receive(:ftp_file).exactly(3).times

      described_class.run_schedulable

      # Just check that there's a sync record
      [product, product2, product3].each {|p| p.reload }
      expect(product.sync_records.first).not_to be_nil
      expect(product2.sync_records.first).not_to be_nil
      expect(product3.sync_records.first).not_to be_nil
    end
  end
end
