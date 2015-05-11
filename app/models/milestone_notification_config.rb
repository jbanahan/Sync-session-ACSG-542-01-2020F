class MilestoneNotificationConfig < ActiveRecord::Base
  # In other words...a config for outputting a 315
  has_many :search_criterions, dependent: :destroy, autosave: true

  def setup_json
    if setup.blank?
      {}
    else
      ActiveSupport::JSON.decode(self.setup)
    end
  end

  def setup_json= hash
    self.setup = ActiveSupport::JSON.encode hash
  end
end

