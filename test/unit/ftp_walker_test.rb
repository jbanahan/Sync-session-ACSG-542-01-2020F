require 'test_helper'
require 'mocha'
require 'net/ftp'

class FtpWalkerTest < ActiveSupport::TestCase

  test "download" do
    dirs = [{:user=>"walktestuser",:module=>"shipment",:search=>"walksrch"},
      {:user=>"wtu2",:module=>"product",:search=>"wpsearch"}]

    User.create!(:company_id=>Company.where(:master=>true).first,:username=>dirs[1][:user],:password=>"pddd12321",:password_confirmation=>"pddd12321",:email=>"test1@aspect9.com")
    u = User.create!(:company_id=>Company.where(:master=>true).first,:username=>dirs[0][:user],:password=>"pddd12321",:password_confirmation=>"pddd12321",:email=>"test@aspect9.com")

    ss = u.search_setups.create!(:name=>dirs[0][:search],:module_type=>dirs[0][:module])

    sys_code = 'ftpwalkertest'
    m = MasterSetup.first
    m.system_code = sys_code
    m.save!
    
    expected_ftp_settings = YAML::load(File.open("#{Rails.root}/config/ftp.yml"))['test']

    script = sequence('script')
    ftp = mock()
    Net::FTP.expects(:open).with(expected_ftp_settings['server']).yields(ftp)

    ftp.expects(:passive=).with(true).in_sequence(script)
    ftp.expects(:login).with(expected_ftp_settings['user'],expected_ftp_settings['password']).in_sequence(script)
    ftp.expects(:chdir).with(sys_code).in_sequence(script)

    #check user directories
    check_subdirectories(ftp,{dirs[0][:user]=>true,dirs[1][:user]=>true,"folder_not_user"=>true,"badfilename.txt"=>false},script)
    #walk user directories
    ftp.expects(:chdir).with("/#{sys_code}/#{dirs[0][:user]}/to_chain").in_sequence(script)
    ftp.expects(:last_response_code).returns('250').in_sequence(script)
    check_subdirectories ftp, {dirs[0][:module]=>true,"badfolder"=>true}, script
    
    #walk module directories
    ftp.expects(:chdir).with("/#{sys_code}/#{dirs[0][:user]}/to_chain/#{dirs[0][:module]}").in_sequence(script)
    ftp.expects(:last_response_code).returns('250').in_sequence(script)
    
    check_subdirectories ftp, {dirs[0][:search]=>true,"badfoldersrch"=>true}, script
    
    #walk search directories
    ftp.expects(:chdir).with("/#{sys_code}/#{dirs[0][:user]}/to_chain/#{dirs[0][:module]}/#{dirs[0][:search]}").in_sequence(script)
    ftp.expects(:last_response_code).returns('250').in_sequence(script)

    #process files
    check_files ftp, {"002.csv"=>true,"badfolder"=>false,"001.csv"=>true}, script
    ftp.expects(:getbinaryfile).with("001.csv","#{Rails.root}/tmp/ftpdown/001.csv").in_sequence(script)
    ftp.expects(:getbinaryfile).with("002.csv","#{Rails.root}/tmp/ftpdown/002.csv").in_sequence(script)

    ftp.expects(:chdir).with("/#{sys_code}/#{dirs[1][:user]}/to_chain").in_sequence(script)
    ftp.expects(:last_response_code).returns('550').in_sequence(script)
    
    File.expects(:new).twice.returns("1","2")

    ImportedFile.any_instance.expects(:attached=).with("1") 
    ImportedFile.any_instance.expects(:attached=).with("2")    
    ImportedFile.any_instance.expects(:save).returns(nil).twice
    ImportedFile.any_instance.expects(:process).returns(nil).twice
    

    FtpWalker.new.go
  end

  def check_files(ftp,files_hash,seq)
    files = files_hash.keys
    ftp.expects(:nlst).returns(files).in_sequence(seq)
    files.each do |f|
      ftp.expects(:chdir).with(f).in_sequence(seq)
      ftp.expects(:last_response_code).returns(files_hash[f] ? "550" : "250").in_sequence(seq)
      ftp.expects(:chdir).with("..") unless files_hash[f]
    end
  end

  def check_subdirectories(ftp,subdirectories_hash,seq)
    folders = subdirectories_hash.keys
    ftp.expects(:nlst).returns(folders).in_sequence(seq)
    folders.each do |f|
      ftp.expects(:chdir).with(f).in_sequence(seq)
      ftp.expects(:last_response_code).returns(subdirectories_hash[f] ? "250" : "550").in_sequence(seq)
      ftp.expects(:chdir).with("..") if subdirectories_hash[f]
    end
  end
end
