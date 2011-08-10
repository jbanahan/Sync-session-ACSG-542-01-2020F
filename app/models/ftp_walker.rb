require 'timeout'
require 'net/ftp'

class FtpWalker

  @@files_being_processed = []


  def go
    sys_code = MasterSetup.get.system_code
    return "no system code" if sys_code.blank?
    file_path = "#{Rails.root}/config/ftp.yml"
    return nil unless File.file? file_path
    ftp_settings = YAML::load(File.open(file_path))[Rails.env]
    log = Logger.new(Rails.root.to_s+"/log/ftp.log")
    @downloaded = {}
    begin
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
    rescue Timeout::Error
      log.error "FTP job timed out!"
    end
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
      e.log_me
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
      unless @@files_being_processed.include? f #another thread has claimed this file
        current_file_path = "#{Rails.root}/tmp/ftpdown/#{f}"
        begin
          @@files_being_processed << f
          ftp.getbinaryfile f, current_file_path 
          if response_good?(ftp) && File.exists?(current_file_path)
            process_file File.new(current_file_path), search_setup
            ftp.delete f
          end
        rescue
          $!.log_me ["Error processing file from ftp walker.","Current File Path: #{current_file_path}"], [current_file_path]
        ensure
          @@files_being_processed.delete f
        end
      end
    end
  end

  def process_file file, search_setup
    imp = search_setup.imported_files.build(:ignore_first_row=>false)
    imp.attached = file
    imp.module_type = search_setup.module_type
    imp.user = search_setup.user
    imp.save!
    imp.process search_setup.user 
    File.delete(file.path) 
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
