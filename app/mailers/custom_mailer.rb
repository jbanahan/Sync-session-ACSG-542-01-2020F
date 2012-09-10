class CustomMailer < ActionMailer::Base
  default :from => 'do-not-reply@chain.io'

  def polo_msl_ack_failure file_content, original_file_name, error_messages
    @file_name = original_file_name
    @errors = error_messages
    m = mail(:to=>'bug@aspect9.com',:subject=>"[Chain.io] MSL+ Enterprise Product Sync Failure")
    m.postmark_attachments = {
      "Name" => original_file_name,
      "Content" => Base64.encode64(file_content),
      "ContentType" => 'text/csv'
    }
    m
  end
end
