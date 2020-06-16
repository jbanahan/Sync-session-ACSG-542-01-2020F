require 'open_chain/s3'

module DownloadS3ObjectSupport
  # The deal with the dispositions below is that pretty much all our downloads for attachments come through this code and any system (like www.vfitrack.net)
  # has always done inline downloads.  When we added proxied_downloads the decision was made to make those download as attachments.  So in order to force
  # the disposition and disposition parameter is required on the HTTP request for the attachments_controller.
  def download_attachment attachment, proxy_download: MasterSetup.get.custom_feature?('Attachment Mask'), disposition: nil
    if proxy_download
      disposition = "attachment" if disposition.blank?
      # This is a sub-optimal method for sending the files.  We're now buffering the entire file's contents into memory.
      # Unfortunately, rails 3 doesn't really give us many options for doing anything else besides short-circuiting the
      # render pipeline and writing an object directly to the response_body that answers to :each.  I'll take the rails
      # send_data option first.  If it becomes an issue, rails 4 has better streaming support or we can use the direct
      # write to response_body instead.
      attachment.download_to_tempfile do |data|
        send_data data.read, stream: true, buffer_size: 4096, disposition: disposition, filename: attachment.attached_file_name, type: attachment.attached_content_type
      end
    else
      redirect_to attachment_secure_url(attachment, disposition: disposition)
    end
  end

  def download_s3_object bucket, path, proxy_download: MasterSetup.get.custom_feature?('Attachment Mask'), expires_in: 1.minute, filename: nil, content_type: nil, disposition: nil
    if proxy_download
      disposition = "attachment" if disposition.blank?
      OpenChain::S3.download_to_tempfile(bucket, path) do |data|
        name = filename.to_s.blank? ? File.basename(path) : filename
        opts = {stream: true, buffer_size: 4096, disposition: disposition, filename: name}
        opts[:type] = content_type unless content_type.blank?

        send_data data.read, opts
      end
    else
      url_opts = {response_content_disposition: content_disposition(disposition, filename)}
      url_opts[:response_content_type] = content_type unless content_type.blank?

      redirect_to OpenChain::S3.url_for(bucket, path, expires_in, url_opts)
    end
  end

  def content_disposition disposition, filename
    disposition = disposition.presence || "inline"

    # If we don't have an exactly standard disposition, the gem blows up...in that case,
    # just return the disposition that was given.  It's possible that
    # a filename was already appended by the caller
    if ["inline", "attachment"].include?(disposition)
      ContentDisposition.format(disposition: disposition, filename: filename, to_ascii: ->(tl_filename) { ActiveSupport::Inflector.transliterate(tl_filename) })
    else
      disposition
    end
  end

  def attachment_secure_url attachment, expires_in: 90.seconds, disposition: "inline", filename: nil
    filename = filename.presence || attachment.attached_file_name
    attachment.secure_url(expires_in, response_content_disposition: content_disposition(disposition, filename))
  end

end
