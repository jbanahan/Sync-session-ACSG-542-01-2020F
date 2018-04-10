# == Schema Information
#
# Table name: attachment_process_jobs
#
#  attachable_id           :integer
#  attachable_type         :string(255)
#  attachment_id           :integer
#  created_at              :datetime         not null
#  error_message           :string(255)
#  finish_at               :datetime
#  id                      :integer          not null, primary key
#  job_name                :string(255)
#  manufacturer_address_id :integer
#  start_at                :datetime
#  updated_at              :datetime         not null
#  user_id                 :integer
#
# Indexes
#
#  attachable_idx                                  (attachable_id,attachable_type)
#  index_attachment_process_jobs_on_attachment_id  (attachment_id)
#  index_attachment_process_jobs_on_user_id        (user_id)
#

require 'open_chain/custom_handler/tradecard/tradecard_pack_manifest_parser'
require 'open_chain/custom_handler/generic_booking_parser'
require 'open_chain/custom_handler/generic_shipment_manifest_parser'

class AttachmentProcessJob < ActiveRecord::Base
  JOB_TYPES ||= {
      'Tradecard Pack Manifest'=>"OpenChain::CustomHandler::Tradecard::TradecardPackManifestParser",
      'Booking Worksheet'=>"OpenChain::CustomHandler::GenericBookingParser",
      'Manifest Worksheet'=>"OpenChain::CustomHandler::GenericShipmentManifestParser"
  }
  belongs_to :attachment, inverse_of: :attachment_process_jobs
  belongs_to :user
  belongs_to :attachable, polymorphic: true, inverse_of: :attachment_process_jobs

  validate :validate_job_name
  validates :attachment, presence: true
  validates :user, presence: true
  validates :attachable, presence: true

  def process opts = {}
    job_class.process_attachment self.attachable, self.attachment, self.user, opts
    self.finish_at = Time.now
    self.save!
  end

  private
  def validate_job_name
    errors.add(:base, "Job name is not recognized.") if JOB_TYPES[self.job_name].blank?
  end

  def job_class
    JOB_TYPES[self.job_name].constantize
  end

  def write_user_message 
    cm = CoreModule.find_by_class_name self.attachable_type
    sub = "#{self.job_name} complete for #{cm.label}"
    sub << " WITH ERROR" unless self.error_message.blank?
    bod = "#{self.job_name} complete for #{cm.label}<br /><br /><a href='#{self.attachable.relative_url}'>Click Here</a> to view the #{cm.label}."
    self.user.messages.create!(subject:sub,body:bod)
  end
end
