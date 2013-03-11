require 'spec_helper'

describe "AllianceProductSupport" do
  class AllianceProductSupportInst
    def remote_file_name; "x.csv"; end
    include OpenChain::CustomHandler::AllianceProductSupport
  end

  it "should send ftp credentials" do
    AllianceProductSupportInst.new.ftp_credentials.should == {:username=>'VFITRACK',:password=>'RL2VFftp',:server=>'ftp2.vandegriftinc.com',:folder=>'to_ecs/alliance_products',:remote_file_name=>'x.csv'}
  end
end
