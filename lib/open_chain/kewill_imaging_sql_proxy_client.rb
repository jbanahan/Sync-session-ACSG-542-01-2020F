require 'open_chain/sql_proxy_client'

module OpenChain; class KewillImagingSqlProxyClient < SqlProxyClient

  def self.proxy_config_key
    "kewill_imaging_sql_proxy"
  end

  def request_images_added_between start_time, end_time, customer_numbers, s3_bucket, sqs_queue
    utc_start_time = start_time.in_time_zone("UTC").iso8601
    utc_end_time = end_time.in_time_zone("UTC").iso8601

    params = {start_date: utc_start_time, end_date: utc_end_time}

    customer_numbers = Array.wrap(customer_numbers).map {|c| c.to_s.upcase }
    params[:customer_numbers] = customer_numbers if customer_numbers.length > 0

    request 'kewill_updated_documents', params, {s3_bucket: s3_bucket, sqs_queue: sqs_queue}, {swallow_error: false}
  end

  def request_images_for_file file_number, s3_bucket, sqs_queue
    params = {file_no: file_number.to_i}
    request 'async_kewill_documents_for_file', params, {s3_bucket: s3_bucket, sqs_queue: sqs_queue}, {swallow_error: false}
  end

end; end