
# This class extends StrionIO to add the ability to define filename and content type values
# for loading Paperclip attachments from a StringIO buffer, rather than Tempfiles
class StringIOAttachment < StringIO
  attr_accessor :original_filename, :content_type
end

class StringIOAttachmentAdapter < Paperclip::StringioAdapter

end

Paperclip.io_adapters.register StringIOAttachmentAdapter do |target|
  StringIOAttachmentAdapter === target
end

# This is a Paperclip validator (which piggy backs off rails validators) that executes a virus scan
# using the configured virus scanner from the registry.  It should scan every new file that enters
# the system.
module Paperclip; module Validators; class AttachmentAntiVirusValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    # We only ever need to scan attachments where the file itself present and is being staged (.ie it's a new file)
    # We don't need to scan the file every single time the attachment record is saved
    return if record.respond_to?(:skip_virus_scan) && record.skip_virus_scan == true

    attachment = record.public_send(attribute)
    # If the file isn't staged, that means that this is not an initial upload of the file, ergo, there's no reason
    # we need to scan it.  It's already been scanned.  Don't waste cycles redownloading the file and then re-scanning.
    return unless attachment&.file? && attachment&.staged?
    file = nil
    begin
      file = Paperclip.io_adapters.for(value)
      if !OpenChain::AntiVirus::AntiVirusRegistry.safe?(file.path)
        record.errors[attribute] << "File '#{value.original_filename}' has been flagged as having a virus."
      end
    ensure
      if file&.tempfile
        file.tempfile.close(true)
      end
    end
  end

  def self.helper_method_name
    :validates_attachment_anti_virus
  end

  module HelperMethods
    def validates_attachment_anti_virus *attr_names
      options = _merge_attributes(attr_names)
      validates_with AttachmentAntiVirusValidator, options.dup
      validate_before_processing AttachmentAntiVirusValidator, options.dup
    end
  end

end; end; end

# This prevents users from uploading certain files with known dangerous file extensions.
# While a user can certainly change the file name and upload the file to get around this, by changing the filename
# it also will negate the default file handler action in Windows.  Meaning if the user really wanted to run the file
# they'd have to rename it before running it....which in nearly all cases negates the attack vector, since the attack
# generally relies on not needing the user to do anything.
module Paperclip; module Validators; class AttachmentExtensionBlacklistValidator < ActiveModel::EachValidator

  # This blacklist is pretty much just Outlook's standard blacklist.
  EXTENSION_BLACKLIST = Set.new(['.bat', '.chm', '.cmd', '.com', '.cpl', '.crt', '.exe', '.hlp', '.hta', '.inf',
    '.ins', '.isp', '.jse', '.lnk', '.mdb', '.ms', '.pcd', '.pif', '.reg', '.scr', '.sct', '.shs', '.vb', '.ws']).freeze

  def validate_each(record, attribute, value)
    file_name = value.original_filename
    return if file_name.blank?

    extension = File.extname(file_name).to_s.downcase
    if blacklisted?(extension)
      record.errors[attribute] << "File '#{file_name}' has an illegal file type of '#{extension}'."
    end
  end

  def blacklisted? extension
    EXTENSION_BLACKLIST.include?(extension)
  end

  def self.helper_method_name
    :validates_attachment_extension_blacklist
  end

  module HelperMethods
    def validates_attachment_extension_blacklist *attr_names
      options = _merge_attributes(attr_names)
      validates_with AttachmentExtensionBlacklistValidator, options.dup
      validate_before_processing AttachmentExtensionBlacklistValidator, options.dup
    end
  end

end; end; end

# This call adds the virus scanner and extension blacklist to the validations.
# I'm not a fan of how this has to be added directly to ActiveRecord::Base, but that's also how all
# the other Paperclip validators work too, so I'm doing it this way as well.
ActiveRecord::Base.send(:extend, Paperclip::Validators::AttachmentAntiVirusValidator::HelperMethods)
ActiveRecord::Base.send(:extend, Paperclip::Validators::AttachmentExtensionBlacklistValidator::HelperMethods)

# The following sets up the anti virus scanner as a required validator on every single class that utilizes
# paperclip's `has_attached_file` method.  This forces every single attachment added to be virus scanned.
module Paperclip; class HasAttachedFile

  def add_required_validations
    options = Paperclip::Attachment.default_options.deep_merge(@options)
    if options[:validate_media_type] != false
      name = @name
      @klass.validates_media_type_spoof_detection name,
        :if => ->(instance) { instance.send(name).dirty? }
    end
    @klass.validates_attachment @name, anti_virus: true
    @klass.validates_attachment @name, extension_blacklist: true
  end

end; end;

# This is a fix for paperclips spoof detector.  It's there to prevent people from uploading
# files to your application with content-types that don't align with reality (html as images).
# To do so, it compares the content-type given by the browser upload (or extracted using the file extension)
# against the output of the `file -b --mime` system command.  The issue is that this ends up conflicting
# on several file types since the file command is not consistent across OSes or versions of OSes.
# It also ends up not correctly identifying MS files that our system generates (or even official onces
# for some Linux server versions)
#
# That being the case, I'm going to address the ACTUAL issue called out in the security report,
# file purporting to be 'image/jpeg' but are actual html files, and let anything else through.
#
# https://robots.thoughtbot.com/paperclip-security-release
#
# So, in essence, if the file's media type is 'image' (via the user supplied content-type or the file extension version),
# we'll do the spoof check.  Otherwise, we'll skip it.
#
Paperclip::MediaTypeSpoofDetector.class_eval do

  alias_method :original_spoofed?, :spoofed?

  def spoofed?
    return false unless supplied_media_type == "image"

    return original_spoofed?
  end

end
