##########################################
# Coverity is the code analysis tool that Maersk uses to do static code analysis / security scanning.
#
# There are two components to it, the analysis tool, which is a command line program that you install and run on your workstation
# and the web application.
#
# The web application is found here: http://coverity-connect.cdpipeline.apmoller.net:8080
#
# NOTE: The web application is ONLY accessible when your machine is connected to the Maersk network, it is not accessible via the public internet.
#
# You must have a username and password to log into the application...I'm not entirely sure how to get a login.  Maybe via Service Now?
#
# Once you have a login, you should make sure you have the ability to administer the 'Vandegrift' project and the 'openchain' stream
#
# Once you have the level of access, you should be able to run code scans.
#
# To do this you must install the scanning application and obtain the license file.
# 
# The application can be downloaded directly through the coverity site by clicking the Help menu and selecting the Downloads option.  Scroll to the 
# Tools section (lower left side of popup), change the "Select a package" select box to choose the install package for your operating system.
#
# Download the file, and run it, installing it somewhere on your machine (I just chose my Downloads dir).  Record the install directory, you'll need it
# to set up the rake task.
#
# Directly below the coverity download is the license download...choose the license.dat file.  
# Download it and place it somewhere safe (I just chose to save it in the coverity install directory)
#
# #######################################
#         TASKS
# #######################################
#
# `rake coverity:setup` - This task is required to be run exactly once before scanning.  It simply gathers some information required to initiate all the other
# scanning steps and stores them in a config file.  It then initializes the coverity scanner config using a coverity tool.
#
#########################################
#
# `rake coverity:analyze` - This task runs the actual analysis step that does the security scanning.
#
#########################################
# 
# `rake coverity:commit` - This task commits the analysis to the Coverity server.
#
# NOTE: The coverity server is NOT publicly addressable, therefeore in order for this command to complete, it must be run from a system that can connect
# to the Maersk network.  
#
# For cases where your code is on a system that is not Maersk network accessible and you have another system that IS accessible, you can install
# coverity on that other system (download it from the same spot you downloaded the coverity install on your dev machine) and copy the contents
# of the .coverity/build directory to that machine.  You can then adjust any paths from the commit task's command line to match the required paths on 
# the new instance.  With the --dir option pointing the the location you copied the .config/build directory to on the new machine.
#
# This is really annoying but the only way around the network limitation that I could find. 
##############################################

namespace :coverity do
  desc "Configures coverity code scanner."

  task setup: :environment do
    coverity_test = lambda do |dir|
      if Dir.exist?(dir) && File.exist?(Pathname.new(dir).join("bin").join("cov-configure").to_s)
        nil
      else
        "#{dir} does not appear to be a valid coverity install directory.  Please enter a valid directory."
      end
    end
    coverity_config = {}
    coverity_config["coverity_install_directory"] = get_user_response "Enter Coverity installation directory", input_test: coverity_test
    coverity_config["license_file_path"] = get_user_response("Enter Coverity license file path", input_test: file_exists_test)
    coverity_config["server"] = get_user_response("Enter Coverity server url", default_value: coverity_url)
    coverity_config["username"] = get_user_response("Enter your Coverity server username", input_test: non_blank_test("Username"))
    coverity_config["authentication_key"] = get_user_response("Enter path to authentication key (Optional: If not provided, password will be required when sending scans to coverity)", input_test: file_exists_test(allow_blank: true))
    
    write_coverity_config_file(coverity_config)
    coverity_config = coverity_config_file

    if !coverity_config_exists?
      FileUtils.mkdir_p Pathname.new(coverity_project_path).join("config").to_s
      sh coverity_command(coverity_config, "cov-configure"), "--config",  coverity_config_path, "--ruby"
    else
      puts "================================================================================================================"
      puts ""
      puts "#{coverity_config_path} configuration already exists. Remove it and re-run 'rake coverity:setup' if you wish to regenerate the config file."
      puts ""
      puts "================================================================================================================"
    end
  end

  desc "Runs coverity build and analyzer."
  task analyze: :environment do
    config = coverity_setup
    
    sh(coverity_command(config, "cov-build"), "--dir", coverity_build_path, "--config", coverity_config_path, "--fs-capture-search", ".", "--no-command")

    # We need to strip all the environment stuff that bundler adds (thus the usage of 'with_original_env' and then make sure to add back in the Gemfile location)
    # Coverity appears to utilize a stripped down ruby and it doesn't properly handle scanning for a Gemfile (wtf?)
    # Thus, we can feed the Gemfile location via an env var to the subprocess
    bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    Bundler.with_original_env do 
      sh({"BUNDLE_GEMFILE" => bundle_gemfile}, coverity_command(config, "cov-analyze"), "--dir",  coverity_build_path, "--all", "--webapp-security", "--security-file", coverity_license_path(config))
    end
  end

  desc "Submits coverity scan data to Coverity web application."
  task commit: :environment do
    config = coverity_setup

    command_line = [
      coverity_command(config, "cov-commit-defects"),
      "--dir",
      coverity_build_path,
      "--security-file",
      config["license_file_path"],
      "--url",
      config["server"],
      "--stream",
      coverity_stream
    ]

    if config['authentication_key'].blank?
      command_line << "--user"
      command_line << config["username"]
      command_line << "--password"
      command_line << get_user_response("Enter Coverity password", input_test: non_blank_test("Password"))
    else
      command_line << "--auth-key-file"
      command_line << config['authentication_key']
    end

    sh *command_line
  end
end

def coverity_bin config
  "#{coverity_base(config)}/bin"
end

def coverity_command config, command
  "#{coverity_bin(config)}/#{command}"
end

def coverity_config
  config = coverity_config_file
  raise "No coverity configuration yml found.  Please run 'rake coverity:setup' to generate it." if config.blank?
  config
end

def coverity_setup
  config = coverity_config
  raise "Coverity must be installed to the #{coverity_base(config)} directory." unless File.exists?("#{coverity_bin(config)}/cov-analyze")
  raise "Expected to find a coverity license file in #{coverity_license_path(config)}.  Download it from the Coverity web application." unless File.exists?(coverity_license_path(config))
  config
end

def coverity_config_path
  "#{coverity_project_path}/config/open_chain.xml"
end

def coverity_project_path
  "#{project_directory}/.coverity"
end

def coverity_config_exists?
  File.exists? coverity_config_path
end

def coverity_build_path
  "#{coverity_project_path}/build"
end

def coverity_license_path config
  config["license_file_path"]
end

def coverity_url
  "http://coverity-connect.cdpipeline.apmoller.net:8080"
end

def coverity_stream
  "openchain"
end

def coverity_base config
  config["coverity_install_directory"]
end

def coverity_config_file
  config_file = config_file_path
  if File.exists?(config_file)
    YAML::load_file(config_file)
  else
    {}
  end
end

def write_coverity_config_file config_json
  config_file = Pathname.new(config_file_path)
  FileUtils.mkdir_p(config_file.parent.to_s)
  File.open(config_file.to_s, "w") { |f| f << config_json.to_yaml }
end

def config_file_path
  Pathname.new(coverity_project_path).join("config").join("coverity-config.yml").to_s
end

def project_directory
  Rails.root.expand_path.to_s
end

def get_user_response message, default_value: nil, input_test: nil
  message += "[Default = #{default_value}]" unless default_value.nil?
  message += ": "

  valid = false
  value = nil
  while(!valid) do 
    STDOUT.print message
    STDOUT.flush
    value = STDIN.gets.strip
    if !default_value.nil? && value.blank?
      value = default_value
    end
    value

    if input_test
      error = input_test.call(value)
      valid = error.blank?
      puts error unless valid
    else
      valid = true
    end
  end

  value
end

def file_exists_test allow_blank: false
  lambda do |file_path| 
    if allow_blank && file_path.blank?
      nil
    else
      File.exist?(file_path) ? nil : "Path #{file_path} does not exist."
    end
  end
end

def non_blank_test value_name
  lambda {|value| value.blank? ? "#{value_name} cannot be blank." : nil }
end