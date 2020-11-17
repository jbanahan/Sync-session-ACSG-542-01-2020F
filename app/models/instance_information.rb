# == Schema Information
#
# Table name: instance_informations
#
#  created_at    :datetime         not null
#  host          :string(255)
#  id            :integer          not null, primary key
#  last_check_in :datetime
#  name          :string(255)
#  role          :string(255)
#  updated_at    :datetime         not null
#  version       :string(255)
#

class InstanceInformation < ActiveRecord::Base
  has_many :upgrade_logs, :dependent => :destroy

  # check in with database, the hostname variable only needs to be passed in test cases
  def self.check_in hostname = nil
    h = hostname.blank? ? MasterSetup.rails_config_key(:hostname) : hostname
    ii = InstanceInformation.find_or_initialize_by host: h
    ii.last_check_in = Time.zone.now
    ii.version = MasterSetup.current_code_version
    ii.name = server_name
    ii.role = server_role
    ii.save
    ii
  end

  # This is the value of the "Name" AWS tag for the ec2 instance the code is currently running on.
  def self.server_name
    @@server_name ||= tag_value("Name")
  end

  # This is the value of the "Role" AWS tag for the ec2 instance the code is currently running on.
  # It currently should be one of: "Web" (web server) or "Job Queue" (delayed job queue runner)
  def self.server_role
    @@server_role ||= tag_value("Role")
  end

  # This is the value of the "Group" AWS tag for the ec2 instance the code is currently running on.
  # This tag is used to group servers together that belong to the same deployment instance for a specific
  # customer deployment (.ie a full stack deploy for a single customer).
  def self.deployment_group
    @@deployment_group ||= tag_value("Group")
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
    read_file(tag_path(tag_name))
  end

  def self.read_file path
    IO.read(path).strip
  rescue Errno::ENOENT
    ""
  end
  private_class_method :read_file
end
