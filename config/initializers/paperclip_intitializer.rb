
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