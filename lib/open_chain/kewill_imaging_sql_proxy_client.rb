require 'open_chain/sql_proxy_client'

module OpenChain; class KewillImagingSqlProxyClient < SqlProxyClient

  def self.proxy_config_file
    Rails.root.join('config', 'kewill_imaging_sql_proxy.yml')
  end

  def request_images_added_between start_time, end_time, s3_bucket, sqs_queue
    utc_start_time = start_time.in_time_zone("UTC").iso8601
    utc_end_time = end_time.in_time_zone("UTC").iso8601

    params = {start_date: utc_start_time, end_date: utc_end_time}

    request 'kewill_updated_documents', params, {s3_bucket: s3_bucket, sqs_queue: sqs_queue}, {swallow_error: false}
  end

end; end