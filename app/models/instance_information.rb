class InstanceInformation < ActiveRecord::Base

  has_many :upgrade_logs, :dependent => :destroy

  #check in with database, the hostname variable only needs to be passed in test cases
  def self.check_in hostname = nil
    h = hostname.blank? ? `hostname`.strip : hostname
    ii = InstanceInformation.find_or_initialize_by_host h
    ii.last_check_in = 0.seconds.ago
    ii.version = MasterSetup.current_code_version
    ii.name = server_name
    ii.role = server_role
    ii.save
    ii
  end

  def self.server_name
    # These values could be cached, but I don't think they'll be called often enough
    # to warrant that
    tag_value("Name")
  end

  def self.server_role
    # These values could be cached, but I don't think they'll be called often enough
    # to warrant that
    tag_value("Role")
  end

  def self.webserver?
    server_role == "Web"
  end

  def self.job_queue?
    server_role == "Job Queue"
  end

  # This method primarily exists for testing purposes

  # The /etc/aws-fs directory is populated via a startup process running
  # on the servers.  It directly queries aws for the tag values associated
  # with the instance this server is running on.
  def self.tag_path tag_name
    "#{tag_base_dir}/#{tag_name}"
  end

  def self.tag_base_dir
    "/etc/aws-fs/tags"
  end

  def self.tag_value tag_name
    path = tag_path(tag_name)
    File.exists?(path) ? File.read(path).strip : ""
  end
end
