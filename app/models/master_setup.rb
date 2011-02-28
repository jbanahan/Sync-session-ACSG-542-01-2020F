class MasterSetup < ActiveRecord::Base
  def version
    Rails.root.join("config","version.txt").read
  end

  def self.init_base_setup
    m = MasterSetup.first
    if m.nil?
      m = MasterSetup.create!(:uuid => UUIDTools::UUID.timestamp_create.to_s)
    end
  end
end
