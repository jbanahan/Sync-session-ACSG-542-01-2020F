module IntegrationParserSupport
  #get the S3 path for the last file used to update this entry (if one exists)
  def last_file_secure_url(expires_in=60.seconds)
    return nil unless has_last_file?
    AWS::S3.new(AWS_CREDENTIALS).buckets[self.last_file_bucket].objects[self.last_file_path].url_for(:read,:expires=>expires_in,:secure=>true).to_s
  end

  def has_last_file?
    # This method is basically only here so that the view helper can determine if there is a last file
    # without having to generate a url (which involves an HTTP request to S3 so we don't do it unless we have to)
    !self.last_file_bucket.blank? && !self.last_file_path.blank?
  end
end
