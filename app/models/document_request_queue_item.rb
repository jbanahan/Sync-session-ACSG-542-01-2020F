# == Schema Information
#
# Table name: document_request_queues
#
#  created_at :datetime
#  id         :integer          not null, primary key
#  identifier :string(255)
#  locked_at  :datetime
#  locked_by  :string(255)
#  request_at :datetime
#  system     :string(255)
#  updated_at :datetime
#
# Indexes
#
#  index_document_request_queues_on_system_and_identifier  (system,identifier) UNIQUE
#  index_document_request_queues_on_updated_at             (updated_at)
#

class DocumentRequestQueueItem < ActiveRecord::Base

  attr_accessible :identifier, :locked_at, :locked_by, :request_at, :system

  def self.enqueue_kewill_document_request file_number, request_delay_minutes: nil
    enqueue_item("Kewill", file_number, request_delay_minutes: request_delay_minutes)
  end

  def self.enqueue_fenix_document_request transaction_number, request_delay_minutes: nil
    enqueue_item("Fenix", transaction_number, request_delay_minutes: request_delay_minutes)
  end

  def self.enqueue_item system, identifier, request_delay_minutes: nil
    val = false
    request_at = Time.zone.now
    request_at = (request_at + request_delay_minutes.to_i.minutes) if request_delay_minutes.to_i != 0

    item = DocumentRequestQueueItem.where(system: system, identifier: identifier).first_or_initialize
    if item.persisted?
      # If the item already exists, just touch it to update the updated_at that way the queue will
      # wait another X amount of time before requesting the file (since the file is being accessed frequently)
      # The goal here is to end up actually waiting until traffic on the file has died down and thus
      # submit the minimal amount of requests required.
      item.update! request_at: request_at
      val = true
    else
      begin
        item.request_at = request_at
        item.save!
        val = true
      rescue ActiveRecord::RecordNotUnique => e
        # Don't care...it means something else just created the item, which ultimately is exactly what we wanted.
      end
    end

    val
  end
  private_class_method :enqueue_item
end
