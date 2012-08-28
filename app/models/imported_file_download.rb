class ImportedFileDownload < ActiveRecord::Base
  belongs_to :imported_file, :inverse_of=>:imported_file_downloads
  belongs_to :user, :inverse_of=>:imported_file_downloads

  has_attached_file :attached,
    :storage => :fog,
    :fog_credentials => FOG_S3,
    :fog_public => false,
    :fog_directory => 'chain-io',
    :path => "#{MasterSetup.get.nil? ? "UNKNOWN" : MasterSetup.get.uuid}/imported_file_download/:id/:filename" #conditional on MasterSetup to allow migrations to run
  before_post_process :no_post

  def attachment_data
    s3 = AWS::S3.new AWS_CREDENTIALS
    s3.buckets[attached.options.fog_directory].objects[attached.path].read
  end
  private
  def no_post
    false
  end
end
