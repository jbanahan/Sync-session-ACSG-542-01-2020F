file = File.join(Rails.root, "config", "stitcher.yml")
if Pathname.new(file).file?
  Rails.application.config.attachment_stitcher = YAML.load_file(file)[Rails.env]
end