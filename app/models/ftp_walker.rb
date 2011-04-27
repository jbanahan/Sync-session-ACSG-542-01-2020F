require 'timeout'
require 'net/ftp'

class FtpWalker

  def go
  #this will need a lot more config to be multi-user, multi-file, but just getting Vandegrift going right now
    sys_code = MasterSetup.first.system_code
    return "no system code" if sys_code.blank?
    file_path = "#{Rails.root}/config/ftp.yml"
    return nil unless File.file? file_path
    ftp_settings = YAML::load(File.open(file_path))[Rails.env]
    log = Logger.new(Rails.root.to_s+"/log/ftp.log")
    @downloaded = {}
    begin
      Timeout::timeout(90) {
        port = ftp_settings['port']
        port = "21" if port.nil?
        connect(ftp_settings['server'],port) do |f|
          f.passive = true
          f.login ftp_settings['user'], ftp_settings['password'] 
          return unless change_directory f, sys_code #go to home directory for local system
          user_directories = subdirectories f
          user_directories.each do |ud|
            user = User.where(:username=>ud).first
            unless user.nil?
              if change_directory f, "/#{sys_code}/#{ud}/to_chain"
                module_directories = subdirectories f
                module_directories.each do |md|
                  mod = CoreModule.find_by_class_name md, true
                  unless mod.nil?
                    if change_directory f, "/#{sys_code}/#{ud}/to_chain/#{md}"
                      search_directories = subdirectories f
                      search_directories.each do |sd|
                        ss = user.search_setups.where(:module_type=>md,:name=>sd).first
                        unless ss.nil?
                          if change_directory f, "/#{sys_code}/#{ud}/to_chain/#{md}/#{sd}"
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

  def connect server, port=21, &block
    ftp = nil
    begin
      ftp = Net::FTP.new
      ftp.connect server, port
      yield ftp
    rescue => e
      OpenMailer.send_generic_exception(e).deliver
      raise e
    ensure
      ftp.close if !ftp.nil? && !ftp.closed?
    end
  end

  def change_directory ftp, destination
    begin
      ftp.chdir destination
    rescue Net::FTPPermError => err
      if ftp.last_response_code == '550'
        return false
      else
        raise err
      end
    end
    return true
  end

  def process_files ftp, file_list, search_setup
    ["#{Rails.root}/tmp","#{Rails.root}/tmp/ftpdown"].each {|p| Dir.mkdir(p) unless File.directory?(p)}
    file_list.each do |f|
      ftp.getbinaryfile f, "#{Rails.root}/tmp/ftpdown/#{f}"
      ftp.delete f
      @downloaded[File.new("#{Rails.root}/tmp/ftpdown/#{f}")] = search_setup
    end
  end

  def run_imports
    @downloaded.each do |file,search_setup|
      imp = search_setup.imported_files.build(:ignore_first_row=>false)
      imp.attached = file
      imp.module_type = search_setup.module_type
      imp.user = search_setup.user
      imp.save
      imp.process search_setup.user 
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
      if is_file ftp, f
        rval << f
      end
    end
    rval
  end

  def is_file ftp, filename
    begin
      ftp.chdir filename
      #wasn't a file, move back up
      ftp.chdir ".."
      return false
    rescue Net::FTPPermError => err
      if ftp.last_response_code=='550' #yes it is a file
        return true
      else
       raise err
      end
    end
  end

  def response_good?(ftp)
    ftp.last_response_code.to_s[0]=="2"
  end
end
