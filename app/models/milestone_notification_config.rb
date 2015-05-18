class MilestoneNotificationConfig < ActiveRecord::Base
  # In other words...a config for outputting a 315
  has_many :search_criterions, dependent: :destroy, autosave: true

  OUTPUT_STYLE_MBOL_CONTAINER_SPLIT ||= "mbol_container"
  OUTPUT_STYLES ||= {OUTPUT_STYLE_MBOL_CONTAINER_SPLIT => "Split on MBOL/Container Numbers", "" => "Standard"}
  validates :output_style, inclusion: {in: OUTPUT_STYLES.keys}

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

