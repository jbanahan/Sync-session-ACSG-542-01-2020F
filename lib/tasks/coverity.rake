# Coverity is the code analysis tool that Maersk uses to do security scanning.
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
# Download the file, and run it, using the install of #{path_to_open_chain}/.coverity/coverity (obviously, fill in #path_to_open_chain with the correct path on your systm)
#
# Directly below the coverity download is the license download...choose the license.dat file.  Download it and place it in the #{path_to_open_chain}/.coverity/config directory (creating the directory if it doesn't exist yet)
#
#
# From there, you will want to run the configure task a single time to set up the scanner: rake coverity:configure
#
# To run a coverity scan: rake coverity:analyze
#
# To submit the results of the scan: rake coverity:commit
#
# NOTE: In order for the commit to function, it MUST be run from a machine that is on the Maersk network.  Coverity is not publicly accessible.

namespace :coverity do
  desc "Configures coverity code scanner."
  
  task configure: :environment do
    coverity_setup?
    if !coverity_config_exists
      sh "#{coverity_command("cov-configure")} --config #{coverity_config_path} --ruby"
    else
      puts "================================================================================================================"
      puts ""
      puts ".coverity/config/open_chain.xml configuration already exists. Remove it if you wish to regenerate a config file."
      puts ""
      puts "================================================================================================================"
    end
  end

  desc "Runs coverity build and analyzer."
  task analyze: :environment do
    coverity_setup?
    raise "No coverity configuration found.  Please run 'rake coverity:configure' to generate it." unless coverity_config_exists?

    sh "#{coverity_command("cov-build")} --dir #{coverity_build_path} --config #{coverity_config_path} --fs-capture-search . --no-command"
    sh "#{coverity_command("cov-analyze")} --dir #{coverity_build_path} --all --webapp-security --security-file #{coverity_license_path}"
  end

  desc "Submits coverity scan data to Coverity web application."
  task commit: :environment do
    coverity_setup?

    STDOUT.print "Enter Coverity username: "
    STDOUT.flush
    username = STDIN.gets.strip

    STDOUT.print "Enter Coverity password: "
    STDOUT.flush
    password = STDIN.gets.strip

    sh "#{coverity_command("cov-commit-defects")} --dir #{coverity_build_path} --security-file #{coverity_license_path} --host #{coverity_hostname} --port #{coverity_port} --user #{username} --password #{password} --stream #{coverity_stream}"
  end

end

def coverity_bin
  ".coverity/coverity/bin"
end

def coverity_command command
  "#{coverity_bin}/#{command}"
end

def coverity_setup?
  raise "Coverity must be installed to the .coverity/coverity directory." unless File.exists?("#{coverity_bin}/cov-analyze")
  raise "Expected to find a coverity license file in #{coverity_license_path}.  Download it from the Coverity web application." unless File.exists?(coverity_license_path)
end

def coverity_config_path
  ".coverity/config/open_chain.xml"
end

def coverity_config_exists?
  File.exists? coverity_config_path
end

def coverity_build_path
  ".coverity/build"
end

def coverity_license_path
  ".coverity/config/license.dat"
end

def coverity_hostname
  "coverity-connect.cdpipeline.apmoller.net"
end

def coverity_port
  "8080"
end

def coverity_stream
  "openchain"
end