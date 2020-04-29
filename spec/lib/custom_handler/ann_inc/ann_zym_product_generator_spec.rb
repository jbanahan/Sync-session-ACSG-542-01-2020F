describe OpenChain::CustomHandler::AnnInc::AnnZymProductGenerator do
  def run_to_array generator=described_class.new
    @tmp = generator.sync_csv
    CSV.read @tmp.path, col_sep:'|' # these are pipe delimited files
  end
  after :each do
    @tmp.unlink if @tmp
  end
  before :all do
    @cdefs = described_class.prep_custom_definitions [:approved_date, :approved_long, :long_desc_override, :origin, :article, :related_styles]
  end
  after :all do
    CustomDefinition.where('1=1').destroy_all
  end

  describe "generate" do
    it "should call FTP whenever row_count > 500" do
      allow_any_instance_of(described_class).to receive(:row_count).and_return(501, 501, 200)
      expect_any_instance_of(described_class).to receive(:ftp_file).exactly(3).times
      described_class.generate
    end
  end
  describe "sync_csv" do
    it "should clean newlines and tabs from long description" do
      content_row = {0=>'213', 1=>'US', 2=>"My Long\nDescription\t", 3=>'CA', 4=>'9876543210', 5=>''}
      gen = described_class.new
      expect(gen).to receive(:sync).with(include_headers: false).and_yield(content_row)
      r = run_to_array gen
      expect(r.size).to eq(1)
      expect(r.first).to eq(['213', 'US', 'My Long Description ', 'CA', '9876543210'])
    end
    it "should not quote empty fields" do
      content_row = {0=>'213', 1=>'US', 2=>"", 3=>'', 4=>'9876543210', 5=>''}
      gen = described_class.new
      expect(gen).to receive(:sync).and_yield(content_row)
      @tmp = gen.sync_csv
      r = IO.read(@tmp)
      expect(r).to eq("213|US|||9876543210\n")
    end
  end
  describe "query" do
    before :each do
      @us = Factory(:country, :iso_code=>'US')
    end
    it "should split mulitple countries of origin into separate rows" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], "MX\nCN"
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      expect(r.size).to eq(2)
      expect(r.first).to eq([p.unique_identifier, 'US', 'LD', 'MX', '1234567890'])
      expect(r.last).to eq([p.unique_identifier, 'US', 'LD', 'CN', '1234567890'])
    end
    it "should only return one hts" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], "MX"
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890", line_number:1)
      cls.tariff_records.create!(:hts_1=>"0987654321", line_number:2)
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first).to eq([p.unique_identifier, 'US', 'LD', 'MX', '1234567890'])
    end
    it "should not output style without ZSCR article type" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], 'MX'
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      p2 = Factory(:product)
      p2.update_custom_value! @cdefs[:article], 'ZSCR-X'
      p2.update_custom_value! @cdefs[:origin], 'MX'
      p2.update_custom_value! @cdefs[:approved_long], 'LD'
      cls2 = p2.classifications.create!(:country_id=>@us.id)
      cls2.tariff_records.create!(:hts_1=>"1234567890")
      cls2.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first.first).to eq(p.unique_identifier)
    end
    it "should only output US" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:origin], 'MX'
      p.update_custom_value! @cdefs[:approved_long], 'LD'
      [@us, Factory(:country, :iso_code=>'CN')].each do |c|
        cls = p.classifications.create!(:country_id=>c.id)
        cls.tariff_records.create!(:hts_1=>'1234567890')
        cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      end
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r.first).to eq([p.unique_identifier, 'US', 'LD', 'MX', '1234567890'])
    end
    it "should only output records that need sync" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include = Factory(:product)
      d_cls = dont_include.classifications.create!(:country_id=>@us.id)
      d_cls.tariff_records.create!(:hts_1=>"1234567890")
      d_cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include.sync_records.create!(:trading_partner=>described_class::SYNC_CODE, :sent_at=>1.day.ago, :confirmed_at=>1.minute.ago)
      # reset updated at so that dont_include won't need sync
      ActiveRecord::Base.connection.execute("UPDATE products SET updated_at = '2010-01-01'")
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
    end
    it "should only output approved products" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      dont_include = Factory(:product)
      dont_include.classifications.create!(:country_id=>@us.id).tariff_records.create!(:hts_1=>"1234567890")
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
    end
    it "should use long description override from classification if it exists" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      p.update_custom_value! @cdefs[:approved_long], "Don't use me"
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.update_custom_value! @cdefs[:long_desc_override], "Other long description"
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago
      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[0][2]).to eq("Other long description")
    end

    it "should handle sending multiple lines for related styles" do
      p = Factory(:product, unique_identifier:'M-Style')
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p.update_custom_value! @cdefs[:related_styles], "P-Style\nT-Style"

      r = run_to_array
      expect(r.size).to eq(3)
      expect(r[0][0]).to eq(p.unique_identifier)
      expect(r[1][0]).to eq("P-Style")
      expect(r[2][0]).to eq("T-Style")
    end

    it "should handle sending multiple lines for related styles and countries" do
      p = Factory(:product, unique_identifier:'M-Style')
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      # Use the country split as well so we make sure both line explosions are working together
      p.update_custom_value! @cdefs[:origin], "MX\nCN"
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p.update_custom_value! @cdefs[:related_styles], "P-Style\nT-Style"

      r = run_to_array
      expect(r.size).to eq(6)
      expect(r[0][0]).to eq("M-Style")
      expect(r[1][0]).to eq("M-Style")
      expect(r[2][0]).to eq("P-Style")
      expect(r[3][0]).to eq("P-Style")
      expect(r[4][0]).to eq("T-Style")
      expect(r[5][0]).to eq("T-Style")
    end

    it "should not output same record twice based on fingerprint" do
      p = Factory(:product)
      p.update_custom_value! @cdefs[:article], 'ZSCR'
      cls = p.classifications.create!(:country_id=>@us.id)
      cls.tariff_records.create!(:hts_1=>"1234567890")
      cls.update_custom_value! @cdefs[:approved_date], 1.day.ago

      p2 = Factory(:product)
      p2.update_custom_value! @cdefs[:article], 'ZSCR'
      cls2 = p2.classifications.create!(:country_id=>@us.id)
      cls2.tariff_records.create!(:hts_1=>"1234567890")
      cls2.update_custom_value! @cdefs[:approved_date], 1.day.ago

      r = run_to_array
      expect(r.size).to eq(2)

      p.update_attributes(updated_at:1.day.from_now) # shouldn't matter because hash doesn't change
      cls2.tariff_records.first.update_attributes(hts_1:'987654321') # should change hash forcing new record

      r = run_to_array
      expect(r.size).to eq(1)
      expect(r[0][0]).to eq(p2.unique_identifier)
    end
  end

  describe "sync_code" do
    it "should have sync code" do
      expect(described_class.new.sync_code).to eq('ANN-ZYM')
    end
  end

  describe "ftp_credentials" do
    it "should send proper credentials" do
      expect(described_class.new.ftp_credentials).to eq({:server=>'ftp2.vandegriftinc.com', :username=>'VFITRACK', :password=>'RL2VFftp', :folder=>'to_ecs/Ann/ZYM', :protocol=>"sftp"})
    end

    it "uses qa folder if instructed" do
      expect(described_class.new(env: :qa).ftp_credentials[:folder]).to eq "to_ecs/ANN/ZYM-TEST"
    end
  end
end
