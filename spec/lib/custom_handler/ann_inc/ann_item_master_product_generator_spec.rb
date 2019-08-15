describe OpenChain::CustomHandler::AnnInc::AnnItemMasterProductGenerator do
  subject { described_class.new "public_key_path" => 'spec/fixtures/files/vfitrack-passphraseless.gpg.key' }

  let(:cdefs) { subject.cdefs }
  let(:us) { Factory(:country, iso_code: "US") }
  let(:ca) { Factory(:country, iso_code: "CA") }
  let(:product_1) do 
    prod = Factory(:product, unique_identifier: "uid 1")
    prod.find_and_set_custom_value cdefs[:approved_long], "approved\u00A0\r\n|\"long 1\"\r"
    prod.find_and_set_custom_value cdefs[:related_styles], "uid 3\nuid 4"
    prod.save!
    prod
  end
  let(:classi_1_1) do 
    cl = Factory(:classification, product: product_1, country: us)
    cl.find_and_set_custom_value cdefs[:classification_type], "Multi"
    cl.find_and_set_custom_value cdefs[:long_desc_override], "long\r\ndescr 1 1\r"
    cl.find_and_set_custom_value cdefs[:approved_date], cl.updated_at - 2.days
    cl.save!
    t = Factory(:tariff_record, classification: cl, hts_1: "123456789", line_number: 1)
    t.update_custom_value! cdefs[:set_qty], 5
    Factory(:tariff_record, classification: cl, hts_1: "987654321", line_number: 2)
    cl
  end
  let(:classi_1_2) do 
    cl = Factory(:classification, product: product_1, country: ca)
    cl.update_custom_value! cdefs[:approved_date], cl.updated_at - 2.days
    Factory(:tariff_record, classification: cl, hts_1: "135791011", line_number: 1)
    cl
  end
  let(:product_2) do 
    prod = Factory(:product, unique_identifier: "uid 2")
    prod.update_custom_value! cdefs[:approved_long], "approved long 2"
    prod
  end
  let(:classi_2_1) do 
    cl = Factory(:classification, product: product_2, country: us)
    cl.find_and_set_custom_value cdefs[:approved_date], cl.updated_at - 2.days
    cl.find_and_set_custom_value cdefs[:classification_type], "Decision"
    cl.find_and_set_custom_value cdefs[:long_desc_override], "long descr 2 1"
    cl.save!
    Factory(:tariff_record, classification: cl, hts_1: "24681012", line_number: 1)
    cl
  end

  def load_all
    classi_1_1; classi_1_2; classi_2_1
  end

  describe "generate" do
    before { load_all }

    it "FTPs encrypted files" do
      file_1 = double "synced file 1"
      file_2 = double "synced file 2"
      encrypted_file_1 = double "encrypted file 1"
      encrypted_file_2 = double "encrypted file 1"
      
      expect(subject).to receive(:sync_csv).ordered do
        subject.instance_variable_set(:@row_count, 1)
        file_1
      end

      expect(subject).to receive(:sync_csv).ordered do
        subject.instance_variable_set(:@row_count, 1)
        file_2
      end

      expect(subject).to receive(:sync_csv).ordered do
        subject.instance_variable_set(:@row_count, 0)
        nil
      end
      expect(file_1).to receive(:close)
      expect(file_2).to receive(:close)
      expect(subject).to receive(:encrypt_file).with(file_1).and_yield(encrypted_file_1)
      expect(subject).to receive(:encrypt_file).with(file_2).and_yield(encrypted_file_2)
      expect(subject).to receive(:ftp_file).with(encrypted_file_1, {remote_file_name: "118340_ITEMMASTER_VFI_20190315023000.txt.gpg"})
      expect(subject).to receive(:ftp_file).with(encrypted_file_2, {remote_file_name: "118340_ITEMMASTER_VFI_20190315023000_v2.txt.gpg"})

      # converts to Eastern time
      now = DateTime.new(2019,3,15,6,30)
      Timecop.freeze(now) { subject.generate "118340_ITEMMASTER_VFI_" }
    end

    it "always sends at least one file" do
      file = double "synced file"
      encrypted_file = double "encrypted file"

      expect(subject).to receive(:sync_csv).ordered do
        # simulate blank result
        subject.instance_variable_set(:@row_count, 0)
        file
      end

      expect(file).to receive(:close)
      expect(subject).to receive(:encrypt_file).with(file).and_yield(encrypted_file)
      expect(subject).to receive(:ftp_file).with(encrypted_file, {remote_file_name: "118340_ITEMMASTER_VFI_20190315023000.txt.gpg"})

      # converts to Eastern time
      now = DateTime.new(2019,3,15,6,30)
      Timecop.freeze(now) { subject.generate "118340_ITEMMASTER_VFI_" }
    end
  end

  describe "sync_csv" do
    it "returns expected output" do
      load_all
      now = DateTime.new(2019,3,15,6,30)
      file = Timecop.freeze(now) { subject.sync_csv }
      file.rewind     
      lines = file.read.split("\n")
      expect(lines[0]).to eq "118340|20190315T023000|||long descr 1 1||0||0|||||||5|||123456789|||||0|0||0|0||0|0||||0||0||Multi|uid 1|LADIES"
      expect(lines[1]).to eq "118340|20190315T023000|||long descr 1 1||0||0|||||||5|||123456789|||||0|0||0|0||0|0||||0||0||Multi|uid 3|LADIES"
      expect(lines[2]).to eq "118340|20190315T023000|||long descr 1 1||0||0|||||||5|||123456789|||||0|0||0|0||0|0||||0||0||Multi|uid 4|LADIES"
      expect(lines[3]).to eq "118340|20190315T023000|||long descr 2 1||0||0|||||||1|||24681012|||||0|0||0|0||0|0||||0||0||Decision|uid 2|LADIES"
      file.close
    end

    it "uses Approved Long Description if Long Description Override is missing" do
      classi_1_1.update_custom_value! cdefs[:long_desc_override], nil
      now = DateTime.new(2019,3,15,6,30)
      file = Timecop.freeze(now) { subject.sync_csv }
      file.rewind     
      lines = file.read.split("\n")
      expect(lines[0]).to eq %Q(118340|20190315T023000|||approved? /"long 1"||0||0|||||||5|||123456789|||||0|0||0|0||0|0||||0||0||Multi|uid 1|LADIES)
    end

    it "collapses empty strings" do
      classi_1_1.reload
      tr = classi_1_1.tariff_records.first
      tr.update! hts_1: ""
      now = DateTime.new(2019,3,15,6,30)
      file = Timecop.freeze(now) { subject.sync_csv }
      file.rewind     
      lines = file.read.split("\n")
      expect(lines[0]).to eq "118340|20190315T023000|||long descr 1 1||0||0|||||||5||||||||0|0||0|0||0|0||||0||0||Multi|uid 1|LADIES"
    end
  end

  describe "sync_code" do
    it "returns correct sync code" do
      expect(subject.sync_code).to eq "ANN-ITEM-MASTER"
    end
  end

  describe "ftp_credentials" do
    let(:ms) { stub_master_setup }

    it "returns credentials for production" do
      expect(ms).to receive(:production?).and_return true
      expect(subject.ftp_credentials).to eq({server: 'connect.vfitrack.net', username: 'www-vfitrack-net', password: 'phU^`kN:@T27w.$', 
                                             folder: "to_ecs/Ann/ITEM_MASTER", protocol: 'sftp', port: 2222})
    end

    it "returns credentials for test" do
      expect(ms).to receive(:production?).and_return false
      expect(subject.ftp_credentials).to eq({server: 'connect.vfitrack.net', username: 'www-vfitrack-net', password: 'phU^`kN:@T27w.$', 
                                             folder: "to_ecs/Ann/ITEM_MASTER_TEST", protocol: 'sftp', port: 2222})
    end
  end

  describe "query" do
    it "returns results for US classifications, including only one tariff" do
      load_all
      results = ActiveRecord::Base.connection.execute subject.query
      expect(results.count).to eq 2
      res = []
      results.each{ |r| res << r }
      row_1, row_2 = res
      expect(row_1).to eq [product_1.id, "uid 1", "long\r\ndescr 1 1\r", "approved\u00A0\r\n|\"long 1\"\r", "123456789", "Multi", "uid 3\nuid 4", 5]
      expect(row_2).to eq [product_2.id, "uid 2", "long descr 2 1", "approved long 2", "24681012", "Decision", nil, 0]
    end

    it "limits number of results" do
      load_all
      expect(subject).to receive(:max_results).and_return 1
      results = ActiveRecord::Base.connection.execute subject.query
      expect(results.count).to eq 1
    end

    it "excludes results that have been synced since the last update" do
      load_all
      sync_date = product_1.updated_at + 1.day
      product_1.sync_records.create! sent_at: sync_date , confirmed_at: sync_date + 5.minutes, trading_partner: "ANN-ITEM-MASTER"
      results = ActiveRecord::Base.connection.execute subject.query
      expect(results.count).to eq 1
      expect(results.first).to eq [product_2.id, "uid 2", "long descr 2 1", "approved long 2", "24681012", "Decision", nil, 0]
    end

    it "excludes results that are missing an approved date" do
      load_all
      classi_1_1.update_custom_value! cdefs[:approved_date], nil
      results = ActiveRecord::Base.connection.execute subject.query
      expect(results.count).to eq 1
    end

    it "excludes results approved today for initial sync" do
      load_all
      classi_1_1.update_custom_value! cdefs[:approved_date], Time.zone.now.in_time_zone("UTC")
      results = ActiveRecord::Base.connection.execute subject.query
      expect(results.count).to eq 1
    end

    it "accepts 'custom where'" do
      generator = described_class.new where: "WHERE products.unique_identifier = 'uid 2'"
      load_all
      results = ActiveRecord::Base.connection.execute generator.query
      expect(results.count).to eq 1
      expect(results.first).to eq [product_2.id, "uid 2", "long descr 2 1", "approved long 2", "24681012", "Decision", nil, 0]
    end
  end

end
