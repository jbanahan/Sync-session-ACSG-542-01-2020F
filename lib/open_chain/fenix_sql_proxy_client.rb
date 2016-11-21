require 'open_chain/sql_proxy_client'

module OpenChain; class FenixSqlProxyClient < SqlProxyClient

  def self.proxy_config_file
    Rails.root.join('config', 'fenix_sql_proxy.yml')
  end

  def request_images_added_between start_time, end_time, s3_bucket, sqs_queue
    utc_start_time = start_time.in_time_zone("UTC").iso8601
    utc_end_time = end_time.in_time_zone("UTC").iso8601

    params = {start_date: utc_start_time, end_date: utc_end_time}

    request 'fenix_updated_documents', params, {s3_bucket: s3_bucket, sqs_queue: sqs_queue}, {swallow_error: false}
  end

  def request_images_for_transaction_number transaction_number, s3_bucket, sqs_queue
    return if transaction_number.to_s.blank? 

    request 'fenix_documents_for_transaction', {transaction_number: transaction_number}, {s3_bucket: s3_bucket, sqs_queue: sqs_queue}, {swallow_error: false}
  end

  def request_lvs_child_transactions transaction_number
    return if transaction_number.to_s.blank? 

    request 'lvs_child_transactions', {transaction_number: transaction_number.to_s}, {}, {swallow_error: false}
  end

end; end
