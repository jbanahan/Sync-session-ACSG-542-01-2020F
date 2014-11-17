class LinkableAttachmentImportRule < ActiveRecord::Base

  validates :path, :presence=>true, :uniqueness=>true
  validates :model_field_uid, :presence=>true

  # Are there any linkable attachment import rules for model fields associated with the given class
  def self.exists_for_class? klass
    reload_cache
    @@link_cache.include?(klass)
  end
  # import the give file to create a LinkableAttachment based on the first matching rule
  # file_obj = the file or file's path
  # original_file_name = the original file name when the file was provided by the customer
  # original_path = the original path where the file was left on the server
  # value_override = force the matching value to be the given value if set
  # returns LinkableAttachment if created, otherwise nil
  def self.import file_obj, original_filename, original_path, value_override = nil
    file = file_obj.respond_to?(:exists?) ? file_obj : File.new(file_obj)
    rule = find_import_rule(original_path)
    r = nil
    if rule
      Attachment.add_original_filename_method file
      file.original_filename= original_filename
      val = value_override.blank? ? get_value_from_filename(original_filename) : value_override 
      r = LinkableAttachment.create!(:model_field_uid=>rule.model_field_uid,:value=>val)
      a = r.build_attachment 
      a.attached = file
      a.save!
    end
    r
  end

  def self.find_import_rule original_path
    LinkableAttachmentImportRule.where(:path=>original_path).first
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

  def self.reload_cache
    @@link_cache ||= nil
    @@link_cache_updated_at ||= nil
    last_rule = LinkableAttachmentImportRule.order('updated_at DESC').first
    return if !@@link_cache.nil? && (last_rule.nil? || @@link_cache_updated_at == last_rule.updated_at)
    load_cache
  end

  def self.load_cache
    @@link_cache = Set.new
    @@link_cache_updated_at = nil
    LinkableAttachmentImportRule.scoped.each do |r|
      @@link_cache_updated_at = r.updated_at if @@link_cache_updated_at.nil? || r.updated_at > @@link_cache_updated_at
      mf = ModelField.find_by_uid(r.model_field_uid)
      next if mf.blank?
      @@link_cache << mf.core_module.klass
    end
  end

  def self.process_from_s3 bucket, path, opts = {}
    opts = {original_filename: File.basename(path), original_path: Pathname.new(path).split[0].to_s}.merge opts
    OpenChain::S3.download_to_tempfile(bucket, path, original_filename: opts[:original_filename]) do |tmp|
      linkable = LinkableAttachmentImportRule.import(tmp, opts[:original_filename], opts[:original_path])
      if linkable && !linkable.errors.blank?
        e = StandardError.new linkable.errors.full_messages.join("\n")
        e.log_me ["Failed to link S3 file #{path} using filename #{opts[:original_filename]}"]
      end
    end
  end
end
