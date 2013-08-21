class InstanceInformation < ActiveRecord::Base

  has_many :upgrade_logs, :dependent => :destroy

  #check in with database, the hostname variable only needs to be passed in test cases
  def self.check_in hostname = nil
    h = hostname.blank? ? `hostname`.strip : hostname
    ii = InstanceInformation.find_or_initialize_by_host h
    ii.last_check_in = 0.seconds.ago
    ii.version = MasterSetup.current_code_version
    ii.save
    ii
  end

end
