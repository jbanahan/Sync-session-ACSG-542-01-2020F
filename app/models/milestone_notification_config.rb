class MilestoneNotificationConfig < ActiveRecord::Base
  # In other words...a config for outputting a 315
  has_many :search_criterions, dependent: :destroy, autosave: true

  OUTPUT_STYLE_MBOL_CONTAINER_SPLIT ||= "mbol_container"
  OUTPUT_STYLE_STANDARD ||= "standard"
  OUTPUT_STYLE_MBOL ||= "mbol"
  OUTPUT_STYLE_HBOL ||= "hbol"
  OUTPUT_STYLES ||= {OUTPUT_STYLE_MBOL_CONTAINER_SPLIT => "Split on MBOL/Container Numbers", OUTPUT_STYLE_STANDARD => "Standard - One 315 per Entry", OUTPUT_STYLE_MBOL => "Split on MBOL - One 315 per MBOL", OUTPUT_STYLE_HBOL => "Split on HBOL - One 315 per HBOL"}
  validates :output_style, inclusion: {in: OUTPUT_STYLES.keys}
  validates_inclusion_of :module_type, in: [CoreModule::ENTRY.class_name, CoreModule::SECURITY_FILING.class_name], message: "is not valid."

  def setup_json
    if setup.blank?
      []
    else
      ActiveSupport::JSON.decode(self.setup)
    end
  end

  def setup_json= hash
    self.setup = ActiveSupport::JSON.encode hash
  end
end

