require 'timeout'
require 'net/ftp'

class FtpWalker

  def go
  #this will need a lot more config to be multi-user, multi-file, but just getting Vandegrift going right now
    file_path = "#{Rails.root}/config/ftp.yml"
    return nil unless File.file? file_path
    ftp_settings = YAML::load(File.open(file_path))[Rails.env]
    log = Logger.new(Rails.root.to_s+"/log/ftp.log")
    @downloaded = {}
    begin
      Timeout::timeout(90) {
        Net::FTP.open(ftp_settings['server']) do |f|
          f.passive = true
          f.login ftp_settings['user'], ftp_settings['password'] 
          sys_code = MasterSetup.first.system_code
          f.chdir sys_code #go to home directory for local system
          return unless response_good? f
          user_directories = subdirectories f
          user_directories.each do |ud|
            user = User.where(:username=>ud).first
            unless user.nil?
              f.chdir "/#{sys_code}/#{ud}/to_chain"
              if response_good? f
                module_directories = subdirectories f
                module_directories.each do |md|
                  mod = CoreModule.find_by_class_name md, true
                  unless mod.nil?
                    f.chdir "/#{sys_code}/#{ud}/to_chain/#{md}"
                    if response_good? f
                      search_directories = subdirectories f
                      search_directories.each do |sd|
                        ss = user.search_setups.where(:module_type=>md,:name=>sd).first
                        unless ss.nil?
                          f.chdir "/#{sys_code}/#{ud}/to_chain/#{md}/#{sd}"
                          if response_good? f
                            file_list = files f
                            file_list.sort!
                            process_files f, file_list, ss
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      } 
    rescue Timeout::Error
      log.error "FTP job timed out!"
    end
    run_imports
  end

  class DownloadedFile
    attr_accessor :username, :module_type, :search_name, :file
  end

  private

  def process_files ftp, file_list, search_setup
    ["#{Rails.root}/tmp","#{Rails.root}/tmp/ftpdown"].each {|p| Dir.mkdir(p) unless File.directory?(p)}
    file_list.each do |f|
      ftp.getbinaryfile f, "#{Rails.root}/tmp/ftpdown/#{f}"
      @downloaded[File.new("#{Rails.root}/tmp/ftpdown/#{f}")] = search_setup
    end
  end

  def run_imports
    @downloaded.each do |file,search_setup|
      imp = search_setup.imported_files.build(:filename=>@downloaded,:size=>file.size,:ignore_first_row=>false)
      imp.attached = file
      imp.save
      imp.process
    end
  end

#get the subdirectories for the current working directory and return the ftp object back to its original state
  def subdirectories(ftp)
    files = ftp.nlst
    rval = []
    files.each do |f| 
      ftp.chdir f
      if response_good? ftp
        rval << f
        ftp.chdir ".."
      end
    end
    rval
  end

  def files ftp
    files = ftp.nlst
    rval = []
    files.each do |f| 
      ftp.chdir f
      if response_good? ftp
        ftp.chdir ".."
      else
        rval << f
      end
    end
    rval
  end

  def response_good?(ftp)
    ftp.last_response_code.to_s[0]=="2"
  end
end
