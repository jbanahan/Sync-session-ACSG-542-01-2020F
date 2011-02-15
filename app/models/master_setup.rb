class MasterSetup < ActiveRecord::Base
  def version
    Rails.root.join("config","version.txt").read
  end
end
