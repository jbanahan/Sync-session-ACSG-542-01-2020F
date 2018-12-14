require 'spec_helper'

describe Port do
  context 'validations' do
    it 'should only allow 5 digit schedule k codes' do
      good = '12345'
      p = Port.new(:schedule_k_code=>good)
      expect(p.save).to eq(true)
      ['1234','123a5',' 12345'].each do |bad|
        p = Port.new(:schedule_k_code=>bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first).to include "Schedule K"
      end
    end
    it 'should only allow 4 digit schedule d codes' do
      good = '1234'
      p = Port.new(:schedule_d_code=>good)
      expect(p.save).to eq(true)
      ['123','12345','123a',' 1234'].each do |bad|
        p = Port.new(:schedule_d_code=>bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first).to include "Schedule D"
      end
    end
    it 'should only allow 4 digit CBSA Ports' do
      good = '1234'
      p = Port.new(:cbsa_port=>good)
      expect(p.save).to eq(true)
      ['123','12345','123a',' 1234'].each do |bad|
        p = Port.new(:cbsa_port=>bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first.downcase).to include "cbsa port"
      end
    end
    it 'should only allow 4 digit CBSA Sublocations' do
      good = '1234'
      p = Port.new(:cbsa_sublocation=>good)
      expect(p.save).to eq(true)
      ['123','12345','123a',' 1234'].each do |bad|
        p = Port.new(:cbsa_sublocation=>bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first.downcase).to include "cbsa sublocation"
      end
    end
    it 'should only allow 5 character UN LOCODES' do
      ["ABCDE", "ABC12"].each do |good|
        p = Port.new(:unlocode=>good)
        expect(p.save).to eq(true)
      end

      ['ABC',' ABCDE','abcde'].each do |bad|
        p = Port.new(:unlocode=>bad)
        expect(p.save).to eq(false)
        expect(p.errors.full_messages.first).to include "UN/LOCODE"
      end
    end
  end
  context 'file loaders' do
    it 'should load CBSA info from tab separated file' do
      data = "0922\t9922\tPort Name, Is Here\n4444\t4441\tAnother Port"
      Port.load_cbsa_data data
      expect(Port.all.size).to eq(2)
      [['0922','9922','Port Name, Is Here'],['4444','4441','Another Port']].each do |a|
        p = Port.find_by_cbsa_port a[0]
        expect(p.cbsa_sublocation).to eq(a[1])
        expect(p.name).to eq(a[2])
      end
    end
    it 'should load schedule d csv' do
      data = "\"01\",,\"PORTLAND, ME\"\n,\"0101\",\"PORTLAND, ME\"\n,\"0102\",\"BANGOR, ME\""
      Port.load_schedule_d data
      expect(Port.all.size).to eq(2)
      {"0101"=>"PORTLAND, ME","0102"=>"BANGOR, ME"}.each do |code,name|
        expect(Port.find_by_schedule_d_code(code).name).to eq(name)
      end
    end
    it 'should replace all schedule d records' do
      data = "\"01\",,\"PORTLAND, ME\"\n,\"0101\",\"PORTLAND, ME\"\n,\"0102\",\"BANGOR, ME\""
      Port.load_schedule_d data
      expect(Port.all.size).to eq(2)
      new_data = "\"01\",,\"PORTLAND, ME\"\n,\"4601\",\"JERSEY\"\n,\"0102\",\"B\""
      Port.load_schedule_d new_data
      expect(Port.all.size).to eq(2) #0101 should be gone, 4601 should be added, and 0102 should be updated
      expect(Port.find_by_schedule_d_code("0101")).to be_nil
      expect(Port.find_by_schedule_d_code("4601").name).to eq("JERSEY")
      expect(Port.find_by_schedule_d_code("0102").name).to eq("B")
    end
    it 'should load schedule k csv' do
      data = "01520  Hamilton, ONT                                      Canada\n01527  Clarkson, ONT                                      Canada                  \n01528  Britt, ONT                                         Canada              "
      Port.load_schedule_k data
      expect(Port.all.size).to eq(3)
      expect(Port.find_by_schedule_k_code("01527").name).to eq("Clarkson, ONT, Canada")
    end
    it 'should replace all schedule k records' do
      data = "01520  Hamilton, ONT                                      Canada\n01527  Clarkson, ONT                                      Canada                  \n01528  Britt, ONT                                         Canada              "
      Port.load_schedule_k data
      expect(Port.all.size).to eq(3)
      new_data = "01528  Britt, ONT                                         Canada                \n01530  Lakeview, ONT                                      Canada                  \n01530  Mississauga, ONT                                   Canada                   "
      Port.load_schedule_k new_data
      expect(Port.all.size).to eq(2)
      expect(Port.find_by_schedule_k_code("01520")).to be_nil
      expect(Port.find_by_schedule_k_code("01530")).not_to be_nil
    end
    it 'should use last schedule k record for port description' do
      data = "01530  Lakeview, ONT                                      Canada                  \n01530  Mississauga, ONT                                   Canada                   "
      Port.load_schedule_k data
      expect(Port.all.size).to eq(1)
      expect(Port.find_by_schedule_k_code("01530").name).to eq("Mississauga, ONT, Canada")
    end

    context "UNLOC codes" do
      let (:rows) {
        [["*", "CA", "", ".CANADA", "*","*","*","*","*","*","*"],
         ["*", "CA", "MON", "Montréal", "Montreal", "*", "---4----", "*","*","YUL","*"],
         ["*", "CA", "VAN", "Vancouver", "Vancouver", "*", "1-------", "*","*","*","*"],
         ["*", "CA", "TOR", "Toronto", "Toronto", "*", "1-------", "*","*","*","*"],
         ["*", "CA", "STJ", "St. John's", "St. John's", "*", "--3----", "*","*","*","*"],
         ["*", "CA", "JON", "Jonquière", "Jonquiere", "*", "--3----", "*","*","XJQ","*"]]
      }

      let (:data) do 
        rows.map{ |r| r.map {|v| v.gsub("*", "")}.to_csv }.join("\n").encode("Windows-1252")
      end

      it "loads UNLOC codes, not updating those that already exist, and creating non-1/4 ports that have IATA codes" do
        Factory(:port, name: "Toronto, haha", unlocode: "CATOR")
        Port.load_unlocode data
        expect(Port.count).to eq 4
        mon = Port.where(unlocode: "CAMON").first
        expect(mon.name).to eq "Montréal"
        expect(mon.iata_code).to eq "YUL"
        van = Port.where(unlocode: "CAVAN").first
        expect(van.name).to eq "Vancouver"
        expect(van.iata_code).to be_nil
        expect(Port.where(unlocode: "CATOR").first.name).to eq "Toronto, haha"
        jon = Port.where(unlocode: "CAJON").first
        expect(jon.name).to eq "Jonquière"
        expect(jon.iata_code).to eq "XJQ"
      end

      it "overwrites existing codes when indicated" do
        Factory(:port, name: "Montreal, haha", unlocode: "CAMON")
        Port.load_unlocode data, true
        expect(Port.count).to eq 4
        mon = Port.where(unlocode: "CAMON").first
        expect(mon.name).to eq "Montréal"
        expect(mon.iata_code).to eq "YUL"
        expect(Port.where(unlocode: "CAVAN").first.name).to eq "Vancouver"
        expect(Port.where(unlocode: "CATOR").first.name).to eq "Toronto"
      end

      it "assigns name from column E if column D doesn't convert to UTF-8" do
        bad_row = ["*", "CA", "WIN", "Winnip\x81g", "Winnipeg", "*", "---4----", "*","*","*","*"].map { |v| v.gsub("*", "").force_encoding("Windows-1252")}.to_csv
        
        Port.load_unlocode bad_row
        expect(Port.count).to eq 1
        expect(Port.where(unlocode: "CAWIN").first.name).to eq "Winnipeg"
      end
    end
  end

  describe "entry_country" do
    it "should match for schedule d or CBSA" do 
      expect(Port.new(schedule_d_code:'0123').entry_country).to eq('United States')
      expect(Port.new(cbsa_port:'0123').entry_country).to eq('Canada')
      expect(Port.new(schedule_k_code:'0123').entry_country).to be_nil
    end
  end

  describe "search_friendly_port_code" do
    it "should return truncated cbsa_port to match Fenix output" do
      expect(Port.new(cbsa_port:'0123').search_friendly_port_code).to eq('123')
    end
    it "should not return truncated cbsa_port if specified" do
      expect(Port.new(cbsa_port:'0123').search_friendly_port_code(trim_cbsa: false)).to eq('0123')
    end
    it "should not truncate schedule d" do
      expect(Port.new(schedule_d_code:'0123').search_friendly_port_code).to eq('0123')
    end
    it "should not truncate schedule k" do
      expect(Port.new(schedule_k_code:'0123').search_friendly_port_code).to eq('0123')
    end
    it "should not truncate unlocode" do
      expect(Port.new(unlocode:'0123').search_friendly_port_code).to eq('0123')
    end
  end

end
