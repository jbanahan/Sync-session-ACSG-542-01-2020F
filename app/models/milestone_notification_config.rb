# == Schema Information
#
# Table name: milestone_notification_configs
#
#  customer_number    :string(255)
#  enabled            :boolean
#  gtn_time_modifier  :boolean
#  id                 :integer          not null, primary key
#  module_type        :string(255)
#  output_style       :string(255)
#  parent_system_code :string(255)
#  setup              :text(65535)
#  testing            :boolean
#
# Indexes
#
#  idx_milestone_configs_on_type_parent_sys_code_testing  (module_type,parent_system_code,testing)
#  index_milestone_configs_on_type_cust_no_testing        (module_type,customer_number,testing)
#

class MilestoneNotificationConfig < ActiveRecord::Base
  attr_accessible :customer_number, :enabled, :module_type, :output_style, :setup, :testing, :gtn_time_modifier, :parent_system_code

  # In other words...a config for outputting a 315
  has_many :search_criterions, dependent: :destroy, autosave: true

  OUTPUT_STYLE_MBOL_CONTAINER_SPLIT ||= "mbol_container"
  OUTPUT_STYLE_STANDARD ||= "standard"
  OUTPUT_STYLE_MBOL ||= "mbol"
  OUTPUT_STYLE_HBOL ||= "hbol"
  # Split on the Cargo Control Number
  OUTPUT_STYLE_CCN ||= "ccn"
  OUTPUT_STYLES ||= {OUTPUT_STYLE_MBOL_CONTAINER_SPLIT => "Split on MBOL/Container Numbers", OUTPUT_STYLE_STANDARD => "Standard - One 315 per Entry", OUTPUT_STYLE_MBOL => "Split on MBOL - One 315 per MBOL", OUTPUT_STYLE_HBOL => "Split on HBOL - One 315 per HBOL", OUTPUT_STYLE_CCN => "Split on Cargo Control - On 315 per Number"}
  validates :output_style, inclusion: {in: OUTPUT_STYLES.keys}
  validates_inclusion_of :module_type, in: [CoreModule::ENTRY.class_name, CoreModule::SECURITY_FILING.class_name], message: "is not valid."

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

  def fingerprint_fields
    j = setup_json
    if j.is_a?(Array)
      []
    else
      j['fingerprint_fields'].presence || []
    end
  end

  def milestone_fields
    j = setup_json
    if j.is_a?(Array)
      j
    else
      j['milestone_fields'].presence || []
    end
  end
end

