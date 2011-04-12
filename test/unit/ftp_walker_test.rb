require 'test_helper'
require 'mocha'
require 'net/ftp'

class FtpWalkerTest < ActiveSupport::TestCase

  test "with real server" do #dependent on test server being active
    #set system code
    ms = MasterSetup.first
    ms.system_code = "unit-test-sys"
    ms.save!

    company = companies(:master)
    u = company.users.create!(:username=>"unit-test-user",:password=>"pwd12345",:password_confirmation=>"pwd12345",:email=>"unittest@chain.io")
    s = u.search_setups.create!(:name=>"test-search-setup",:module_type=>"Shipment")
    s.search_columns.create!(:model_field_uid=>"shp_ref",:rank=>0)
    s.search_columns.create!(:model_field_uid=>"shp_ven_id",:rank=>1)

    expected_shp_ref = "WithRealServerTestShipment"

    assert Shipment.where(:reference=>expected_shp_ref).blank?, "Shipment shouldn't exist and did."

    #make sample file
    tmp = Tempfile.new(expected_shp_ref)
    tmp << "#{expected_shp_ref},#{companies(:vendor).id}"
    tmp.flush
    tmp.close
    
    #upload sample file
    settings = YAML::load(File.open("#{Rails.root}/config/ftp.yml"))['test']
    ftp = Net::FTP.new
    begin
      ftp.connect settings['server'], settings['port']
      ftp.passive = true
      ftp.login settings['user'], settings['password']
      ftp.chdir "/#{ms.system_code}/#{u.username}/to_chain/shipment/#{s.name}"
      ftp.puttextfile tmp
    ensure
      ftp.close
    end

    FtpWalker.new.go

    r = Shipment.where(:reference=>expected_shp_ref)
    assert r.size==1
    assert r.first.vendor_id==companies(:vendor).id
  end

end
