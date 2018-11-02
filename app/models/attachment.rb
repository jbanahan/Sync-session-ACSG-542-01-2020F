# == Schema Information
#
# Table name: attachments
#
#  alliance_revision       :integer
#  alliance_suffix         :string(255)
#  attachable_id           :integer
#  attachable_type         :string(255)
#  attached_content_type   :string(255)
#  attached_file_name      :string(255)
#  attached_file_size      :integer
#  attached_updated_at     :datetime
#  attachment_type         :string(255)
#  checksum                :string(255)
#  created_at              :datetime         not null
#  id                      :integer          not null, primary key
#  is_private              :boolean
#  source_system_timestamp :datetime
#  updated_at              :datetime         not null
#  uploaded_by_id          :integer
#
# Indexes
#
#  index_attachments_on_attachable_id_and_attachable_type  (attachable_id,attachable_type)
#  index_attachments_on_updated_at                         (updated_at)
#

require 'open_chain/google_drive'
require 'open_chain/s3'

class Attachment < ActiveRecord::Base
  has_attached_file :attached, :path => ":master_setup_uuid/attachment/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :attached
  before_create :sanitize
  before_post_process :no_post

  # Needs to get prepended so it runs before the callbacks that has_attached_file (Paperclip) adds
  before_destroy :record_filename, prepend: true 
  
  belongs_to :uploaded_by, :class_name => "User"
  belongs_to :attachable, polymorphic: true, touch: true

  has_many :attachment_archives_attachments, :dependent=>:destroy
  has_many :attachment_archives, :through=>:attachment_archives_attachments
  has_many :attachment_process_jobs
  
  ARCHIVE_PACKET_ATTACHMENT_TYPE ||= "Archive Packet".freeze

  def web_preview?
    return !self.attached_content_type.nil? && self.attached_content_type.start_with?("image") && !self.attached_content_type.ends_with?('tiff')
  end
  
  def secure_url(expires_in=90.seconds, s3_url_opts = {})
    OpenChain::S3.url_for bucket, attached.path, expires_in, s3_url_opts
  end

  def can_view?(user)
    if self.is_private?
      return user.company.master? && self.attachable.can_view?(user)
    else
      return self.attachable.can_view?(user) && can_view_attachment_type?(user)
    end
  end

  def is_pdf?
    self.attached_content_type.ends_with?('pdf')
  end

  def can_view_attachment_type? user
    view = false
    if self.attachable.is_a?(Entry)
      # Billing Invoice = Alliance Billing
      # Invoice = Fenix
      # Archive Packet = These will have the invoices in them as well, so they need to have access restrictions.
      attachment_type = self.attachment_type.to_s.upcase
      if ["BILLING INVOICE", "INVOICE", ARCHIVE_PACKET_ATTACHMENT_TYPE.upcase].include?(attachment_type) || attachment_type =~ /BILLING INVOICE/
        view = BrokerInvoice.can_view? user, self.attachable
      else
        view = true
      end
    else
      view = true
    end

    view
  end

  #unique name suitable for putting on archive disks
  def unique_file_name
    # Prepend the Document Type (if it exists)
    name = "#{self.id}-#{self.attached_file_name}"
    unless self.attachment_type.blank?
      name = Attachment.get_sanitized_filename "#{self.attachment_type}-#{name}"
    end
    name
  end

  def attachment_file_size_human
    ActionController::Base.helpers.number_to_human_size(self.attached_file_size)
  end

  def self.email_attachments params #hash
    to_address = params[:to_address]
    email_subject = params[:email_subject]
    email_body = params[:email_body]
    full_name = params[:full_name]
    email = params[:email]
    attachments = []
    params[:ids_to_include].each do |attachment_id|
      attachment = Attachment.find(attachment_id)
      tfile = attachment.download_to_tempfile
      Attachment.add_original_filename_method tfile
      tfile.original_filename = attachment.attached_file_name
      tfile.original_filename = attachment.attachment_type + " " + tfile.original_filename if !attachment.attachment_type.blank?
      attachments << tfile
    end
    attachment_buckets = get_buckets_from(attachments)
    email_index = 1; total_emails = attachment_buckets.length

    attachment_buckets.each do |attachments|
      if total_emails > 1
        altered_subject = email_subject + " (#{email_index} of #{total_emails})"
        email_index += 1
        OpenMailer.auto_send_attachments(to_address, altered_subject, email_body, attachments, full_name, email).deliver!
      else
        OpenMailer.auto_send_attachments(to_address, email_subject, email_body, attachments, full_name, email).deliver!
      end
    end
    return true
  ensure
    attachments.each {|tfile| tfile.close! unless tfile.closed?}
  end

  def self.get_buckets_from(attachments)
  final_buckets = [[]]
  attachments.each do |attachment|
    added_to_existing_bucket = false
    if attachment.size >= 10*1020*1024
      final_buckets << [attachment]
    else
      final_buckets.each do |bucket|
        if bucket == []
          bucket << attachment
          added_to_existing_bucket = true
        elsif (bucket.map(&:size).inject(:+) != nil) and (10*1020*1024 - bucket.map(&:size).inject(:+) >= attachment.size)
          bucket << attachment
          added_to_existing_bucket = true
          break
        end
      end
      final_buckets << [attachment] unless added_to_existing_bucket
    end
  end
  final_buckets
end

  # create a hash suitable for json rendering containing all attachments for the given attachable
  def self.attachments_as_json attachable
    r = {attachable:{id:attachable.id,type:attachable.class.to_s},attachments:[]}
    ra = r[:attachments]
    attachable.attachments.each do |att|
      ra << attachment_json(att)
    end
    r
  end

  def self.attachment_json att
    json = {
      id: att.id,
      name: att.attached_file_name, 
      size: att.attachment_file_size_human,
      type: att.attachment_type
    }
    if att.uploaded_by
      json[:user] = {
        id: att.uploaded_by.id, 
        username: att.uploaded_by.username, 
        full_name: att.uploaded_by.full_name
      }
    end
    json
  end

  def self.add_original_filename_method attached_object, filename = nil
    def attached_object.original_filename=(fn); @fn = fn; end
    def attached_object.original_filename; @fn; end

    attached_object.original_filename = filename unless filename.blank?
    nil
  end

  def self.sanitize_filename model, paperclip_name
    instance = paperclip_instance model, paperclip_name
    filename = instance.instance_read(:file_name)

    if filename
      instance.instance_write(:file_name, get_sanitized_filename(filename))
    end
  end

  def self.get_sanitized_filename filename
    # This encodes to latin1 converting unknown chars along the way to _, then back to UTF-8.
    # The encoding translation is necessitated only because our charsets in the database for the filename are latin1
    # instead of utf8, and converting them to utf8 is a process we don't want to deal with at the moment.
    filename = filename.encode("ISO-8859-1", :replace=>"_", :invalid=>:replace, :undef=>:replace).encode("UTF-8")

    # We also want to underscore'ize invalid windows chars from the filename (in cases where you upload a file from
    # a mac and then try to download on windows - browser can't be relied upon do do this for us at this point).
    character_filter_regex = /[\x00-\x1F\/\\:\*\?\"<>\|]/u
    filename = filename.gsub(character_filter_regex, "_")

    # For some reason, some of our users are dumping docs into the system that are like pdf_ or tif_.  They're not sophisticated
    # enough to know how to deal with this...for this reason, I'm stripping any trailing _'s from file extensions because they
    # then cause the filetype detection in paperclip to trip up.
    extension = File.extname(filename)
    if !extension.blank?
      filename = filename.gsub(/_+$/, "")
    end

    filename
  end

  # Downloads attachment data from S3 and pushes it to the google drive account, path given.
  # drive_folder - if nil, file is placed in root of drive account
  # attachmend_id - the attachment id to push
  # overwrite_existing - if false is passed, it will not replace any existing files that may already be in the folder, it will create identically named ones
  def self.push_to_google_drive drive_folder, attachment_id, overwrite_existing: true
    a = Attachment.find attachment_id
    drive_path = File.join((drive_folder ? drive_folder : ""), a.attached_file_name)
    OpenChain::S3.download_to_tempfile(a.bucket, a.path) do |temp|
      OpenChain::GoogleDrive.upload_file drive_path, temp, overwrite_existing: overwrite_existing
    end
  end

  def download_to_tempfile
    if block_given?
      self.class.download_to_tempfile(self.attached, original_file_name:self.attached_file_name, &Proc.new)
    else
      self.class.download_to_tempfile(self.attached, original_file_name:self.attached_file_name)
    end
  end

  def self.download_to_tempfile attached, original_file_name: nil
    if attached
      # Attachments are always in chain-io bucket regardless of environment
      opts = {}
      opts[:original_filename] = original_file_name if original_file_name
      if block_given?
        return OpenChain::S3.download_to_tempfile(bucket(attached), path(attached), opts) do |f|
          yield f
        end
      else
        return OpenChain::S3.download_to_tempfile(bucket(attached), path(attached), opts)
      end
    end
  end

  def stitchable_attachment?
    # The stitching process supports any image format that ImageMagick can convert to a pdf (which is apparently a ton of formats), 
    # for now, we'll just support stitching the major image formats.
    filename = self.attached_file_name
    if filename.blank? && defined?(@destroyed_filename)
      filename = @destroyed_filename
    end
    !self.is_private? && Attachment.stitchable_attachment_extensions.include?(File.extname(filename).try(:downcase))
  end

  def record_filename
    # Paperclip (for some reason) - clears the attached_* attributes during it's destroy callbacks...we actually want
    # to use the filename after it's been deleted internally for something...so record it here.
    @destroyed_filename = self.attached_file_name
    true
  end

  def self.stitchable_attachment_extensions
    ['.tif', '.tiff', '.jpg', '.jpeg', '.gif', '.png', '.bmp', '.pdf']
  end

  def rebuild_archive_packet
    if self.stitchable_attachment? && self.attachable_id && self.attachable_type == "Entry"
      # Just queue a stitch request...if the entry's importer isn't set up for stitching, then the stitch queue handler
      # will just skip the request, no big deal.

      # In cases where an Entry is being deleted, this is going to generate stitch requests for each attachment being
      OpenChain::AllianceImagingClient.delay.send_entry_stitch_request(self.attachable_id)
    end
  end

  # We're aping the custom_file processing api touchpoints here (plus, it's a convenient accessor method anyway)
  def bucket
    self.class.bucket attached
  end

  def self.bucket attached
    attached.try(:options).try(:[], :bucket)
  end

  # We're aping the custom_file processing api touchpoints here (plus, it's a convenient accessor method anyway)
  def path
    self.class.path attached
  end

  def self.path attached
    attached.try(:path)
  end

  private
    def no_post
      false
    end

    def sanitize
      Attachment.sanitize_filename self, :attached
    end

    def self.paperclip_instance model, paperclip_name
      model.send(paperclip_name)
    end
    private_class_method :paperclip_instance
end
