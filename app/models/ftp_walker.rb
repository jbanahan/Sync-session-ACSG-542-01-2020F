require 'timeout'
require 'net/ftp'
class FtpWalker

  def go
  #this will need a lot more config to be multi-user, multi-file, but just getting Vandegrift going right now
    log = Logger.new(Rails.root.to_s+"/log/ftp.log")
    tmp_files = []
    begin
      Timeout::timeout(90) {
        Net::FTP.open('ftp.chain.io') do |f|
          f.debug_mode = true
          f.passive = true
          f.login 'chainroot', 'czft9918#'
          f.chdir 'www-vfitrack-net/integration/to_chain/shipment/trackfeed'
          file_list = f.nlst.sort
          file_list.each do |fname|
            t = Tempfile.new(fname)
            f.getbinaryfile(fname,t.path)
            tmp_files << t
	    f.delete fname
          end
        end
      } 
    rescue Timeout::Error
      log.error "FTP job timed out!"
    end
    s = SearchSetup.where(:name=>'trackfeed',:user_id=>User.where(:username=>"integration").first).first
    tmp_files.each do |tmp|
      imp = s.imported_files.build(:filename => '',:size=>tmp.size,:content_type=>'text/csv',:ignore_first_row=>false)
      imp.attached = File.new(tmp.path)
      imp.save!
      imp.process
    end
  end

end
