module Helpers

  # Use this method when you need to evaluate a full excel row as an array
  # There's some underlying comparison that fails when comparing arrays
  # and using an excel date 
  #
  # ie. sheet.row(0) == [excel_date(Date.new(2013, 1, 1))]
  def excel_date date
    #Excel internally stores date values as days since Jan 1, 1900
    excel_start_date = Date.new(1899, 12, 30).jd
    (date.jd - excel_start_date).to_f
  end

  def stub_paperclip
    # Stub out the actual paperclip save/destroy method, which is what pushes/deletes the files to/from S3
    # Everything else about the attachment process should remain working, the attached_* attributes should
    # be filled in when 'attachment.attached = file' is used, etc.  only difference is no s3 calls should be made
    # ever.
    Paperclip::Attachment.any_instance.stub(:save).and_return true
    Paperclip::Attachment.any_instance.stub(:destroy).and_return true
  end
  
  def allow_api_access user
    use_json
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials "#{user.username}:#{user.api_auth_token}"
  end

  def use_json
    request.env['CONTENT_TYPE'] = 'application/json'
    request.env['HTTP_ACCEPT'] = 'application/json'
  end

  def stub_event_publisher
    OpenChain::EventPublisher.stub(:publish).and_return nil
  end
end