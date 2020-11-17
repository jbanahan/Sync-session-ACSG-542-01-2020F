describe Port do
  context 'validations' do
    it 'onlies allow 5 digit schedule k codes' do
      good = '12345'
      p = described_class.new(schedule_k_code: good)
      expect(p.save).to eq(true)
      ['1234', '123a5', ' 12345'].each do |bad|
        p = described_class.new(schedule_k_code: bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first).to include "Schedule K"
      end
    end

    it 'onlies allow 4 digit schedule d codes' do
      good = '1234'
      p = described_class.new(schedule_d_code: good)
      expect(p.save).to eq(true)
      ['123', '12345', '123a', ' 1234'].each do |bad|
        p = described_class.new(schedule_d_code: bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first).to include "Schedule D"
      end
    end

    it 'onlies allow 4 digit CBSA Ports' do
      good = '1234'
      p = described_class.new(cbsa_port: good)
      expect(p.save).to eq(true)
      ['123', '12345', '123a', ' 1234'].each do |bad|
        p = described_class.new(cbsa_port: bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first.downcase).to include "cbsa port"
      end
    end

    it 'onlies allow 4 digit CBSA Sublocations' do
      good = '1234'
      p = described_class.new(cbsa_sublocation: good)
      expect(p.save).to eq(true)
      ['123', '12345', '123a', ' 1234'].each do |bad|
        p = described_class.new(cbsa_sublocation: bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first.downcase).to include "cbsa sublocation"
      end
    end

    it 'onlies allow 5 character UN LOCODES' do
      ["ABCDE", "ABC12"].each do |good|
        p = described_class.new(unlocode: good)
        expect(p.save).to eq(true)
      end

      ['ABC', ' ABCDE', 'abcde'].each do |bad|
        p = described_class.new(unlocode: bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first).to include "UN/LOCODE"
      end
    end
  end

  context 'file loaders' do
    it 'loads CBSA info from tab separated file' do
      data = "0922\t9922\tPort Name, Is Here\n4444\t4441\tAnother Port"
      described_class.load_cbsa_data data
      expect(described_class.all.size).to eq(2)
      [['0922', '9922', 'Port Name, Is Here'], ['4444', '4441', 'Another Port']].each do |a|
        p = described_class.find_by cbsa_port: a[0]
        expect(p.cbsa_sublocation).to eq(a[1])
        expect(p.name).to eq(a[2])
      end
    end

    it 'loads schedule d csv' do
      data = "\"01\",,\"PORTLAND, ME\"\n,\"0101\",\"PORTLAND, ME\"\n,\"0102\",\"BANGOR, ME\""
      described_class.load_schedule_d data
      expect(described_class.all.size).to eq(2)
      {"0101" => "PORTLAND, ME", "0102" => "BANGOR, ME"}.each do |code, name|
        expect(described_class.find_by(schedule_d_code: code).name).to eq(name)
      end
    end

    it 'replaces all schedule d records' do
      data = "\"01\",,\"PORTLAND, ME\"\n,\"0101\",\"PORTLAND, ME\"\n,\"0102\",\"BANGOR, ME\""
      described_class.load_schedule_d data
      expect(described_class.all.size).to eq(2)
      new_data = "\"01\",,\"PORTLAND, ME\"\n,\"4601\",\"JERSEY\"\n,\"0102\",\"B\""
      described_class.load_schedule_d new_data
      expect(described_class.all.size).to eq(2) # 0101 should be gone, 4601 should be added, and 0102 should be updated
      expect(described_class.find_by(schedule_d_code: "0101")).to be_nil
      expect(described_class.find_by(schedule_d_code: "4601").name).to eq("JERSEY")
      expect(described_class.find_by(schedule_d_code: "0102").name).to eq("B")
    end

    it 'loads schedule k csv' do
      # rubocop:disable Layout/LineLength
      data = "01520  Hamilton, ONT                                      Canada\n01527  Clarkson, ONT                                      Canada                  \n01528  Britt, ONT                                         Canada              "
      # rubocop:enable Layout/LineLength
      described_class.load_schedule_k data
      expect(described_class.all.size).to eq(3)
      expect(described_class.find_by(schedule_k_code: "01527").name).to eq("Clarkson, ONT, Canada")
    end

    it 'replaces all schedule k records' do
      # rubocop:disable Layout/LineLength
      data = "01520  Hamilton, ONT                                      Canada\n01527  Clarkson, ONT                                      Canada                  \n01528  Britt, ONT                                         Canada              "
      # rubocop:enable Layout/LineLength
      described_class.load_schedule_k data
      expect(described_class.all.size).to eq(3)
      # rubocop:disable Layout/LineLength
      new_data = "01528  Britt, ONT                                         Canada                \n01530  Lakeview, ONT                                      Canada                  \n01530  Mississauga, ONT                                   Canada                   "
      # rubocop:enable Layout/LineLength
      described_class.load_schedule_k new_data
      expect(described_class.all.size).to eq(2)
      expect(described_class.find_by(schedule_k_code: "01520")).to be_nil
      expect(described_class.find_by(schedule_k_code: "01530")).not_to be_nil
    end

    it 'uses last schedule k record for port description' do
      # rubocop:disable Layout/LineLength
      data = "01530  Lakeview, ONT                                      Canada                  \n01530  Mississauga, ONT                                   Canada                   "
      # rubocop:enable Layout/LineLength
      described_class.load_schedule_k data
      expect(described_class.all.size).to eq(1)
      expect(described_class.find_by(schedule_k_code: "01530").name).to eq("Mississauga, ONT, Canada")
    end

    context "UNLOC codes" do
      let (:rows) do
        [["*", "CA", "", ".CANADA", "*", "*", "*", "*", "*", "*", "*"],
         ["*", "CA", "MON", "Montréal", "Montreal", "*", "---4----", "*", "*", "YUL", "*"],
         ["*", "CA", "VAN", "Vancouver", "Vancouver", "*", "1-------", "*", "*", "*", "*"],
         ["*", "CA", "TOR", "Toronto", "Toronto", "*", "1-------", "*", "*", "*", "*"],
         ["*", "CA", "STJ", "St. John's", "St. John's", "*", "--3----", "*", "*", "*", "*"],
         ["*", "CA", "JON", "Jonquière", "Jonquiere", "*", "--3----", "*", "*", "XJQ", "*"]]
      end

      let (:data) do
        rows.map { |r| r.map {|v| v.gsub("*", "")}.to_csv }.join("\n").encode("Windows-1252")
      end

      it "loads UNLOC codes, not updating those that already exist, and creating non-1/4 ports that have IATA codes" do
        Factory(:port, name: "Toronto, haha", unlocode: "CATOR")
        described_class.load_unlocode data
        expect(described_class.count).to eq 4
        mon = described_class.where(unlocode: "CAMON").first
        expect(mon.name).to eq "Montréal"
        expect(mon.iata_code).to eq "YUL"
        van = described_class.where(unlocode: "CAVAN").first
        expect(van.name).to eq "Vancouver"
        expect(van.iata_code).to be_nil
        expect(described_class.where(unlocode: "CATOR").first.name).to eq "Toronto, haha"
        jon = described_class.where(unlocode: "CAJON").first
        expect(jon.name).to eq "Jonquière"
        expect(jon.iata_code).to eq "XJQ"
      end

      it "overwrites existing codes when indicated" do
        Factory(:port, name: "Montreal, haha", unlocode: "CAMON")
        described_class.load_unlocode data, true
        expect(described_class.count).to eq 4
        mon = described_class.where(unlocode: "CAMON").first
        expect(mon.name).to eq "Montréal"
        expect(mon.iata_code).to eq "YUL"
        expect(described_class.where(unlocode: "CAVAN").first.name).to eq "Vancouver"
        expect(described_class.where(unlocode: "CATOR").first.name).to eq "Toronto"
      end

      it "assigns name from column E if column D doesn't convert to UTF-8" do
        bad_row = ["*", "CA", "WIN", "Winnip\x81g", "Winnipeg", "*", "---4----", "*", "*", "*", "*"].map { |v| v.gsub("*", "").force_encoding("Windows-1252")}.to_csv

        described_class.load_unlocode bad_row
        expect(described_class.count).to eq 1
        expect(described_class.where(unlocode: "CAWIN").first.name).to eq "Winnipeg"
      end
    end
  end

  describe "entry_country" do
    it "matches for schedule d or CBSA" do
      expect(described_class.new(schedule_d_code: '0123').entry_country).to eq('United States')
      expect(described_class.new(cbsa_port: '0123').entry_country).to eq('Canada')
      expect(described_class.new(schedule_k_code: '0123').entry_country).to be_nil
    end
  end

  describe "search_friendly_port_code" do
    it "returns truncated cbsa_port to match Fenix output" do
      expect(described_class.new(cbsa_port: '0123').search_friendly_port_code).to eq('123')
    end

    it "does not return truncated cbsa_port if specified" do
      expect(described_class.new(cbsa_port: '0123').search_friendly_port_code(trim_cbsa: false)).to eq('0123')
    end

    it "does not truncate schedule d" do
      expect(described_class.new(schedule_d_code: '0123').search_friendly_port_code).to eq('0123')
    end

    it "does not truncate schedule k" do
      expect(described_class.new(schedule_k_code: '0123').search_friendly_port_code).to eq('0123')
    end

    it "does not truncate unlocode" do
      expect(described_class.new(unlocode: '0123').search_friendly_port_code).to eq('0123')
    end
  end

  describe "load_iata_data" do
    it "adds port records from a pipe-delimited IATA file" do
      described_class.create!(iata_code: "EXS", name: "Existing Port")

      data = "AAL|Aalborg Airport|DK|Aalborg\n" +
             "ACC|Kotoka International Airport|GH|Accra\n" +
             "AGP|Málaga Airport|ES|Malaga\n" +
             "EXS|New description should be ignored|EX|Portaporty\n" +
             "NCE|Nice-Côte d'Azur Airport|FR|Nice\n"

      described_class.load_iata_data data

      expect(described_class.count).to eq 5

      expect(described_class.where(iata_code: "AAL", name: "Aalborg Airport").first).not_to be_nil
      expect(described_class.where(iata_code: "ACC", name: "Kotoka International Airport (Accra)").first).not_to be_nil
      expect(described_class.where(iata_code: "AGP", name: "Málaga Airport").first).not_to be_nil
      expect(described_class.where(iata_code: "EXS", name: "Existing Port").first).not_to be_nil
      expect(described_class.where(iata_code: "EXS", name: "New description should be ignored").first).to be_nil
      expect(described_class.where(iata_code: "NCE", name: "Nice-Côte d'Azur Airport").first).not_to be_nil
    end
  end

end
