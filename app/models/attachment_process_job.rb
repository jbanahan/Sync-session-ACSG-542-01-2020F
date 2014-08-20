require 'open_chain/custom_handler/tradecard/tradecard_pack_manifest_parser'

class AttachmentProcessJob < ActiveRecord::Base
  JOB_TYPES ||= {'Tradecard Pack Manifest'=>OpenChain::CustomHandler::Tradecard::TradecardPackManifestParser}
  belongs_to :attachment, inverse_of: :attachment_process_jobs
  belongs_to :user
  belongs_to :attachable, polymorphic: true, inverse_of: :attachment_process_jobs

  validate :validate_job_name
  validates :attachment, presence: true
  validates :user, presence: true
  validates :attachable, presence: true

  def process
    JOB_TYPES[self.job_name].process_attachment self.attachable, self.attachment, self.user
    self.finish_at = Time.now
    self.save!
  end

  private
  def validate_job_name
    errors.add(:base, "Job name is not recognized.") if JOB_TYPES[self.job_name].blank?
  end

  def write_user_message 
    cm = CoreModule.find_by_class_name self.attachable_type
    sub = "#{self.job_name} complete for #{cm.label}"
    sub << " WITH ERROR" unless self.error_message.blank?
    bod = "#{self.job_name} complete for #{cm.label}<br /><br /><a href='#{self.attachable.relative_url}'>Click Here</a> to view the #{cm.label}."
    self.user.messages.create!(subject:sub,body:bod)
  end
end
