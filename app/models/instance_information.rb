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

  #check in with database, the hostname variable only needs to be passed in test cases
  def self.check_in hostname = nil
    h = hostname.blank? ? Rails.application.config.hostname : hostname
    ii = InstanceInformation.find_or_initialize_by_host h
    ii.last_check_in = 0.seconds.ago
    ii.version = MasterSetup.current_code_version
    # Only needed for initial migration run since instance information is referenced in initailizers
    ii.name = server_name if ii.respond_to?(:name=)
    ii.role = server_role if ii.respond_to?(:role=)
    ii.save
    ii
  end

  def self.server_name
    # These values could be cached, but I don't think they'll be called often enough
    # to warrant that
    @@server_name ||= tag_value("Name")
    @@server_name
  end

  def self.server_role
    # These values could be cached, but I don't think they'll be called often enough
    # to warrant that
    @@server_role ||= tag_value("Role")
    @@server_role
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
