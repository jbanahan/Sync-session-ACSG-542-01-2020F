module OpenChain; module AntiVirus; module AntiVirusHelper
  include ActiveSupport::Concern

  def validate_file file
    file = get_file_path(file)
    raise Errno::ENOENT, "#{file}" unless File.file?(file)
    file
  end

  def get_file_path file
    return file.path if file.respond_to?(:path)
    return file.to_path.to_s if file.respond_to?(:to_path)

    # Assume Strings are already file paths
    return file if file.is_a?(String)
    raise "Unexpected file descriptor given. #{file}"
  end

end; end; end;