class LinkableAttachmentImportRule < ActiveRecord::Base

  validates :path, :presence=>true, :uniqueness=>true
  validates :model_field_uid, :presence=>true

  # import the give file to create a LinkableAttachment based on the first matching rule
  # file_obj = the file or file's path
  # original_file_name = the original file name when the file was provided by the customer
  # original_path = the original path where the file was left on the server
  # value_override = force the matching value to be the given value if set
  # returns LinkableAttachment if created, otherwise nil
  def self.import file_obj, original_filename, original_path, value_override = nil
    file = file_obj.respond_to?(:exists?) ? file_obj : File.new(file_obj)
    rule = LinkableAttachmentImportRule.where(:path=>original_path).first
    r = nil
    if rule
      def file.original_filename=(f); @original_filename = f; end
      def file.original_filename; @original_filename; end
      file.original_filename= original_filename
      val = value_override.blank? ? get_value_from_filename(original_filename) : value_override 
      r = LinkableAttachment.create!(:model_field_uid=>rule.model_field_uid,:value=>val)
      a = r.build_attachment 
      a.attached = file
      a.save!
    end
    r
  end

  private
  def self.get_value_from_filename filename
    split = filename.split(' ')
    return split.first if split.size > 1
    split = filename.split('_')
    return split.first if split.size > 1
    split = filename.split('.')
    return split.first if split.size > 1
    return filename 
  end
end
