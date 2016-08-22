require 'spec_helper'

describe OpenChain::CustomHandler::DasProductGenerator do
  #YYYYMMDDHHMMSSLLL-DAPART.DAT
  describe "remote_file_name" do
    it "should be in correct format" do
      expect(described_class.new.remote_file_name).to eq "DAPART.DAT"
    end
  end

  describe "generate" do
    it "should create fixed position file and ftp it" do
      h = described_class.new
      expect(h).to receive(:sync_fixed_position).and_return('x')
      expect(h).to receive(:ftp_file).with('x').and_return('y')
      expect(h.generate).to eq 'y'
    end
  end

  describe "ftp_credentials" do
    it "should send credentials" do
     expect(described_class.new.ftp_credentials).to eq server: 'ftp2.vandegriftinc.com', username: "VFITRACK", password: 'RL2VFftp', folder: 'to_ecs/alliance_products', remote_file_name: "DAPART.DAT"
    end
  end

  describe "auto_confirm?" do
    it "should autoconfirm" do
      expect(described_class.new.auto_confirm?).to be_truthy
    end
  end

  describe "query" do
    before :each do
      @us = Factory(:country, iso_code: 'US')
      @classification = Factory(:classification, :country_id=>@us.id)
      @tariff_record = Factory(:tariff_record, :classification => @classification, :hts_1 => '12345')
      @match_product = @classification.product
      @unit_cost = Factory(:custom_definition, id: 2, module_type: "Product", label:"Unit Cost", data_type: "decimal")
      @coo = Factory(:custom_definition, id: 6, module_type: "Product", label:"COO")
      @match_product.update_custom_value! @unit_cost, 10.5
    end

    it "should not return products that don't need sync" do
      dont_find = Factory(:classification, country_id: @us.id).product
      dont_find.sync_records.create!(trading_partner: described_class::SYNC_CODE, sent_at: 1.minute.ago, confirmed_at: 1.second.ago)
      dont_find.update_attributes(updated_at: 1.day.ago)
      r = Product.connection.execute described_class.new.query
      expect(r.count).to eq(1)
      expect(r.first[1]).to eq(@match_product.unique_identifier)
    end

    it "should return products that do need sync" do
      do_find_classification = Factory(:classification, country_id: @us.id)
      do_find = do_find_classification.product
      find_tariff = Factory(:tariff_record, classification: do_find_classification, hts_1: '23456')
      do_find.update_custom_value! @unit_cost, 10.5
      do_find.update_custom_value! @coo, 'US'
      r = Product.connection.execute described_class.new.query
      expect(r.count).to eq(2)
      expect(r.first[1]).to eq(@match_product.unique_identifier)
      expect(r.to_a[1][1]).to eq(do_find.unique_identifier)
      expect(r.to_a[1][5]).to eq(find_tariff.hts_1)
      expect(r.to_a[1][3]).to eq(10.5)
      expect(r.to_a[1][4]).to eq('US')
    end
  end

  describe "fixed_position_map" do
    it "should return mapping" do
      expect(described_class.new.fixed_position_map).to eq([
        {:len=>15}, #unique identifier
        {:len=>40}, #name
        {:len=>6}, #unit cost
        {:len=>2}, #country of origin
        {:len=>10} #hts
      ])
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      @us = Factory(:country, iso_code: 'US')
      @classification = Factory(:classification, :country_id=>@us.id)
      @tariff_record = Factory(:tariff_record, :classification => @classification, :hts_1 => '12345')
      @match_product = @classification.product
      @unit_cost = Factory(:custom_definition, id: 2, module_type: "Product", label:"Unit Cost", data_type: "decimal")
      @coo = Factory(:custom_definition, id: 6, module_type: "Product", label:"COO")
      @match_product.update_custom_value! @unit_cost, 10.5

      expect_any_instance_of(described_class).to receive(:ftp_file)
      described_class.run_schedulable

      expect(SyncRecord.first.syncable).to eq @match_product
    end
  end
end
