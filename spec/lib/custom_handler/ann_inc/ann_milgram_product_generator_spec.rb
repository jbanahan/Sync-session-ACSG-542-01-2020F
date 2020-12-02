describe OpenChain::CustomHandler::AnnInc::AnnMilgramProductGenerator do
  def run_to_array generator=described_class.new
    @tmp = generator.sync_csv
    CSV.read @tmp.path, {:col_sep=>"\t"}
  end

  after :each do
    @tmp.unlink if @tmp
  end
  before :all do
    @cdefs = described_class.prep_custom_definitions [:approved_date, :approved_long, :long_desc_override, :manual_flag, :oga_flag, :fta_flag, :set_qty, :related_styles]
  end

  after :all do
    CustomDefinition.where('1=1').destroy_all
  end


  context 'query' do
    before :each do
      @ca = create(:country, :iso_code=>'CA')
    end
    it "should only send Canadian tariff" do
      p = create(:product)
      p.update_custom_value! @cdefs[:approved_long], 'PLONG'
      [@ca, create(:country, :iso_code=>'US')].each do |cntry|
        cls = p.classifications.create!(:country_id=>cntry.id)
        cls.tariff_records.create!(:hts_1=>"#{cntry.iso_code}12345678")
        cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      end
      p.classifications.find_by(country: @ca).tariff_records.first.update_custom_value! @cdefs[:set_qty], 2 # the job should clear this since it's not a set
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first).to eq([p.unique_identifier, '', 'PLONG', '', 'CA12345678', 'N', 'N', 'N', 'N'])
    end
    it "should only send approved products" do
      p = create(:product)
      cls = p.classifications.create!(:country_id=>@ca.id)
      cls.tariff_records.create!(:hts_1=>"0012345678")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_find = create(:product)
      dont_find.classifications.create!(:country_id=>@ca.id).tariff_records.create!(:hts_1=>"0012345678")
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first.first).to eq(p.unique_identifier)
    end
    it "should only send products that need sync" do
      p = create(:product)
      cls = p.classifications.create!(:country_id=>@ca.id)
      cls.tariff_records.create!(:hts_1=>"0012345678")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_find = create(:product)
      d_cls = dont_find.classifications.create!(:country_id=>@ca.id)
      d_cls.tariff_records.create!(:hts_1=>"0012345678")
      d_cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_find.sync_records.create!(:trading_partner=>described_class::SYNC_CODE, :sent_at=>1.hour.ago, :confirmed_at=>1.minute.ago)
      ActiveRecord::Base.connection.execute 'UPDATE products SET updated_at = "2010-01-01"' # reset updated at so product doesn't need sync
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first.first).to eq(p.unique_identifier)
    end
    it "should override long description with country specific version" do
      p = create(:product)
      cls = p.classifications.create!(:country_id=>@ca.id)
      cls.tariff_records.create!(:hts_1=>"0012345678")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p.classifications.first.update_custom_value! @cdefs[:long_desc_override], 'LDOV'
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first[2]).to eq('LDOV')
    end
    it "should explode lines that have related styles" do
      p = create(:product)
      [@ca, create(:country, :iso_code=>'US')].each do |cntry|
        cls = p.classifications.create!(:country_id=>cntry.id)
        cls.tariff_records.create!(:hts_1=>"#{cntry.iso_code}12345678")
        cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      end
      p.classifications.find_by(country: @ca).tariff_records.first.update_custom_value! @cdefs[:set_qty], 2 # the job should clear this since it's not a set

      p.update_custom_value! @cdefs[:related_styles], "#{p.unique_identifier}\np-style\nt-style" # uid should not duplicate

      r = run_to_array
      expect(r.size).to eq(3)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[1][0]).to eq("p-style")
      expect(r[2][0]).to eq("t-style")
    end

    context "sets" do
      it "should create 3 rows for two component style" do
        p = create(:product)
        p.update_custom_value! @cdefs[:approved_long], 'LONG'
        cls = p.classifications.create!(:country_id=>@ca.id)
        cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
        tr1 = cls.tariff_records.create!(:hts_1=>"0012345678", :line_number=>1)
        tr2 = cls.tariff_records.create!(:hts_1=>'2222222222', :line_number=>2)
        tr1.update_custom_value! @cdefs[:set_qty], 10
        tr2.update_custom_value! @cdefs[:set_qty], 20
        r = run_to_array
        expect(r).to eq([
          [p.unique_identifier, '', 'LONG', '', '', 'Y', 'N', 'N', 'N'],
          [p.unique_identifier, '1', 'LONG', '10', '0012345678', 'Y', 'N', 'N', 'N'],
          [p.unique_identifier, '2', 'LONG', '20', '2222222222', 'Y', 'N', 'N', 'N'],
        ])
      end
    end
  end

  it "should have sync code" do
    expect(described_class.new.sync_code).to eq('ANN-MIL')
  end

  context "ftp" do
    it "should send proper credentials" do
      expect(described_class.new.ftp_credentials).to eq({:server=>'ftp2.vandegriftinc.com', :username=>'VFITRACK', :password=>'RL2VFftp', :folder=>'to_ecs/Ann/MIL', :protocol=>"sftp"})
    end
  end
end
