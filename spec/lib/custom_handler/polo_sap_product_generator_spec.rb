require 'spec_helper'

describe OpenChain::CustomHandler::PoloSapProductGenerator do
  before :each do
    @g = described_class.new
  end
  describe :sync_code do
    it "should be polo_sap" do
      @g.sync_code.should == 'polo_sap'
    end
  end

  describe :ftp_credentials do
    it "should send proper credentials" do
      @g.ftp_credentials.should == {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ralph_Lauren/sap_prod'}
    end
    it "should set qa folder if :env=>:qa in class initializer" do
      described_class.new(:env=>:qa).ftp_credentials.should == {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>'to_ecs/Ralph_Lauren/sap_qa'}
    end
  end

  describe :before_csv_write do
    before :each do 
      @vals = []
      30.times {|i| @vals << i}
      @vals[3] = "1234567890"
    end
    it "should hts_format HTS value if set type indicator is not X" do
      r = @g.before_csv_write 1, @vals
      @vals[3] = '1234.56.7890'
      r.should == @vals
    end
    it "should clear HTS if set type indicator is X" do
      @vals[9] = 'X'
      r = @g.before_csv_write 1, @vals
      @vals[3] = ''
      r.should == @vals
    end
  end


end
