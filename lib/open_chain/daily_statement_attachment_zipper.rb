require 'open_chain/create_zip_support'

module OpenChain; class DailyStatementAttachmentZipper
  MAX_SIZE = 10_485_760
  
  def self.zip_and_email user_id, statement_id, types, email_opts
    statement = DailyStatement.includes(daily_statement_entries: :entry).find statement_id
    ent_hsh = entries statement, types
    user = User.find user_id
    if ent_hsh.values.flatten.map{ |x| x&.attached_file_size || 0 }.sum > MAX_SIZE
      raise "Total attachment size greater than #{MAX_SIZE} bytes" 
    end
    create_zip_and_email user.email, statement.statement_number, get_lambda(ent_hsh), email_opts
  end

  def self.zip_and_send_message user_id, statement_id, types
    statement = DailyStatement.includes(daily_statement_entries: :entry).find statement_id
    ent_hsh = entries statement, types
    user = User.find user_id
    create_zip_and_send_message user, statement.statement_number, get_lambda(ent_hsh)
  end

  def self.entries statement, types
    ent_hsh = {}
    entries = statement.daily_statement_entries.map(&:entry)
    entries.each { |ent| ent_hsh[ent.entry_number] = ent.attachments.where attachment_type: types }
    ent_hsh
  end

  private_class_method :entries

  def self.get_lambda entry_hash
    lambda do |zip|
      entry_hash.each do |ent_num, atts|
        atts.each do |att|
          io = StringIO.new
          OpenChain::S3.get_data(att.bucket, att.path, io)
          OpenChain::CreateZipSupport::Zipper.add_io_to_zip(zip, "#{ent_num}/#{att.attached_file_name}", io)
        end
      end
    end
  end

  private_class_method :get_lambda

  def self.create_zip_and_email user_email, statement_number, file_operation_lambda, email_opts
    zip_name = "Attachments for Statement #{statement_number}.zip"
    OpenChain::CreateZipSupport::Zipper.create_zip_tempfile(zip_name, file_operation_lambda) do |tempfile|     
      addr = email_opts['email'].presence || user_email 
      email_subject = email_opts['subject'].presence || "Attachments for Statement #{statement_number}"
      email_body = email_opts['body'].presence || "Please find attached your files for Statement #{statement_number}"
      OpenMailer.send_simple_html(addr, email_subject, email_body, [tempfile]).deliver_now
    end
  end

  def self.create_zip_and_send_message user, statement_number, file_operation_lambda
    zip_name = "Attachments for Statement #{statement_number}.zip"
    OpenChain::CreateZipSupport::Zipper.create_zip_tempfile(zip_name, file_operation_lambda) do |tempfile|
      att = Attachment.create! attached: tempfile, uploaded_by: user, attached_file_name: tempfile.original_filename
      msg = user.messages.create! subject: "Attachments for Daily Statement #{statement_number}", 
                                  body: "Click <a href='#{Rails.application.routes.url_helpers.download_attachment_path(id: att.id)}'>here</a> to download attachments."
      msg.attachments << att                                  
    end
  end

  private_class_method :create_zip_and_send_message
end; end
