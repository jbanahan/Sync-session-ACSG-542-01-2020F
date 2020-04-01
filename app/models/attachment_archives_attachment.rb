# == Schema Information
#
# Table name: attachment_archives_attachments
#
#  attachment_archive_id :integer
#  attachment_id         :integer
#  file_name             :string(255)
#  id                    :integer          not null, primary key
#
# Indexes
#
#  arch_id  (attachment_archive_id)
#  att_id   (attachment_id)
#
require 'open_chain/template_util'
class AttachmentArchivesAttachment < ActiveRecord::Base
  attr_accessible :attachment_archive_id, :attachment_id, :file_name

  belongs_to :attachment, :inverse_of=>:attachment_archives_attachments
  belongs_to :attachment_archive, :inverse_of=>:attachment_archives_attachments

  # Defines the output path (including filename) to use when archiving this attachment.
  # The path here is the path relative to the archive root folder for this
  # specific archive instance - ie. AttachmentArchive.name.
  # Use /'s to designate subdirectories.
  def output_path
    # This is assuming we're only archiving entries.
    if attachment_archive.company.attachment_archive_setup.output_path.blank?
      return "#{attachment.attachable.broker_reference}/#{self.file_name}"
    else
      liquid_string = attachment_archive.company.attachment_archive_setup.output_path
      variables = {'attachment' => ActiveRecordLiquidDelegator.new(attachment),
        'archive_attachment' => ActiveRecordLiquidDelegator.new(self),
        'entry' => ActiveRecordLiquidDelegator.new(attachment.attachable)}

      sanitize_path OpenChain::TemplateUtil.interpolate_liquid_string(liquid_string, variables)
    end
  end

  private
  def sanitize_path path
    Pathname.new(path.gsub("", "").squeeze(" ")).each_filename.map { |file|
      Attachment.get_sanitized_filename(file)
    }.join("/")
  end

end
