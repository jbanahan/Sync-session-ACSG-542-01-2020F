
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

# The last of the 4 series "nicely" includes deprecation warnings about
# the 5 series not supporting aws_v1 sdk and rails 3/4.0...which is stupid (don't warn
# me about a future gem version's incompatibility)
# Just monkey patch this warning out.
module Paperclip; class Deprecations
  class << self
    def check
      nil
    end
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
