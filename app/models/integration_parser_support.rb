module IntegrationParserSupport
  #get the S3 path for the last file used to update this entry (if one exists)
  def last_file_secure_url(expires_in=60.seconds)
    return nil if self.last_file_bucket.blank? || self.last_file_path.blank?
    AWS::S3.new(AWS_CREDENTIALS).buckets[self.last_file_bucket].objects[self.last_file_path].url_for(:read,:expires=>expires_in,:secure=>true).to_s
  end
end
