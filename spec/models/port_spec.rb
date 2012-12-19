require 'spec_helper'

describe Port do
  context 'validations' do
    it 'should only allow 5 digit schedule k codes' do
      good = '12345'
      p = Port.new(:schedule_k_code=>good)
      p.save.should == true
      ['1234','123a5',' 12345'].each do |bad|
        p = Port.new(:schedule_k_code=>bad)
        p.save.should == false
        p.errors.full_messages.first.should include "Schedule K"
      end
    end
    it 'should only allow 4 digit schedule d codes' do
      good = '1234'
      p = Port.new(:schedule_d_code=>good)
      p.save.should == true
      ['123','12345','123a',' 1234'].each do |bad|
        p = Port.new(:schedule_d_code=>bad)
        p.save.should == false
        p.errors.full_messages.first.should include "Schedule D"
      end
    end
    it 'should only allow 4 digit CBSA Ports' do
      good = '1234'
      p = Port.new(:cbsa_port=>good)
      p.save.should == true
      ['123','12345','123a',' 1234'].each do |bad|
        p = Port.new(:cbsa_port=>bad)
        p.save.should == false
        p.errors.full_messages.first.downcase.should include "cbsa port"
      end
    end
    it 'should only allow 4 digit CBSA Sublocations' do
      good = '1234'
      p = Port.new(:cbsa_sublocation=>good)
      p.save.should == true
      ['123','12345','123a',' 1234'].each do |bad|
        p = Port.new(:cbsa_sublocation=>bad)
        p.save.should == false
        p.errors.full_messages.first.downcase.should include "cbsa sublocation"
      end
    end
    it 'should only allow 5 character UN LOCODES' do
      good = 'ABCDE'
      p = Port.new(:unlocode=>good)
      p.save.should == true
      ['ABC',' ABCDE','A1234','abcde'].each do |bad|
        p = Port.new(:unlocode=>bad)
        p.save.should == false
        p.errors.full_messages.first.should include "UN/LOCODE"
      end
    end
  end
  context 'file loaders' do
    it 'should load CBSA info from tab separated file' do
      data = "0922\t9922\tPort Name, Is Here\n4444\t4441\tAnother Port"
      Port.load_cbsa_data data
      Port.all.should have(2).ports
      [['0922','9922','Port Name, Is Here'],['4444','4441','Another Port']].each do |a|
        p = Port.find_by_cbsa_port a[0]
        p.cbsa_sublocation.should == a[1]
        p.name.should == a[2]
      end
    end
    it 'should load schedule d csv' do
      data = "\"01\",,\"PORTLAND, ME\"\n,\"0101\",\"PORTLAND, ME\"\n,\"0102\",\"BANGOR, ME\""
      Port.load_schedule_d data
      Port.all.should have(2).ports
      {"0101"=>"PORTLAND, ME","0102"=>"BANGOR, ME"}.each do |code,name|
        Port.find_by_schedule_d_code(code).name.should == name
      end
    end
    it 'should replace all schedule d records' do
      data = "\"01\",,\"PORTLAND, ME\"\n,\"0101\",\"PORTLAND, ME\"\n,\"0102\",\"BANGOR, ME\""
      Port.load_schedule_d data
      Port.all.should have(2).ports
      new_data = "\"01\",,\"PORTLAND, ME\"\n,\"4601\",\"JERSEY\"\n,\"0102\",\"B\""
      Port.load_schedule_d new_data
      Port.all.should have(2).ports #0101 should be gone, 4601 should be added, and 0102 should be updated
      Port.find_by_schedule_d_code("0101").should be_nil
      Port.find_by_schedule_d_code("4601").name.should == "JERSEY"
      Port.find_by_schedule_d_code("0102").name.should == "B"
    end
    it 'should load schedule k csv' do
      data = "01520  Hamilton, ONT                                      Canada\n01527  Clarkson, ONT                                      Canada                  \n01528  Britt, ONT                                         Canada              "
      Port.load_schedule_k data
      Port.all.should have(3).ports
      Port.find_by_schedule_k_code("01527").name.should == "Clarkson, ONT, Canada"
    end
    it 'should replace all schedule k records' do
      data = "01520  Hamilton, ONT                                      Canada\n01527  Clarkson, ONT                                      Canada                  \n01528  Britt, ONT                                         Canada              "
      Port.load_schedule_k data
      Port.all.should have(3).ports
      new_data = "01528  Britt, ONT                                         Canada                \n01530  Lakeview, ONT                                      Canada                  \n01530  Mississauga, ONT                                   Canada                   "
      Port.load_schedule_k new_data
      Port.all.should have(2).ports
      Port.find_by_schedule_k_code("01520").should be_nil
      Port.find_by_schedule_k_code("01530").should_not be_nil
    end
    it 'should use last schedule k record for port description' do
      data = "01530  Lakeview, ONT                                      Canada                  \n01530  Mississauga, ONT                                   Canada                   "
      Port.load_schedule_k data
      Port.all.should have(1).port
      Port.find_by_schedule_k_code("01530").name.should == "Mississauga, ONT, Canada"
    end
  end
end
