require 'open_chain/zip_builder'

module OpenChain; class DailyStatementAttachmentZipper
  MAX_SIZE = 10_485_760

  def self.zip_and_email user_id, statement_id, types, email_opts
    statement = DailyStatement.includes(daily_statement_entries: :entry).find statement_id
    ent_hsh = entries statement, types
    user = User.find user_id
    if ent_hsh.values.flatten.map { |x| x&.attached_file_size || 0 }.sum > MAX_SIZE
      raise "Total attachment size greater than #{MAX_SIZE} bytes"
    end
    create_zip_and_email user.email, statement.statement_number, ent_hsh, email_opts
  end

  def self.zip_and_send_message user_id, statement_id, types
    statement = DailyStatement.includes(daily_statement_entries: :entry).find statement_id
    ent_hsh = entries statement, types
    user = User.find user_id
    create_zip_and_send_message user, statement.statement_number, ent_hsh
  end

  class << self
    private

      def entries statement, types
        ent_hsh = {}
        entries = statement.daily_statement_entries.map(&:entry)
        entries.each { |ent| ent_hsh[ent.entry_number] = ent.attachments.where attachment_type: types }
        ent_hsh
      end

      def create_zip_and_email user_email, statement_number, entry_hash, email_opts
        zip_name = "Attachments for Statement #{statement_number}.zip"
        OpenChain::ZipBuilder.create_zip_builder(zip_name) do |builder|
          download_and_zip_attachments(builder, entry_hash)

          addr = email_opts['email'].presence || user_email
          email_subject = email_opts['subject'].presence || "Attachments for Statement #{statement_number}"
          email_body = email_opts['body'].presence || "Please find attached your files for Statement #{statement_number}"
          OpenMailer.send_simple_html(addr, email_subject, email_body, [builder.to_tempfile]).deliver_now
        end
      end

      def create_zip_and_send_message user, statement_number, entry_hash
        zip_name = "Attachments for Statement #{statement_number}.zip"
        OpenChain::ZipBuilder.create_zip_builder(zip_name) do |builder|
          download_and_zip_attachments(builder, entry_hash)
          file = builder.to_tempfile

          att = Attachment.create! attached: file, uploaded_by: user, attached_file_name: file.original_filename
          msg = user.messages.create! subject: "Attachments for Daily Statement #{statement_number}",
                                      body: "Click <a href='#{Rails.application.routes.url_helpers.download_attachment_path(id: att.id)}'>here</a> to download attachments."
          msg.attachments << att
        end
      end

      def download_and_zip_attachments zip_builder, entry_hash
        entry_hash.each_pair do |ent_num, attachments|
          attachments.each do |attachment|
            io = StringIO.new
            OpenChain::S3.get_data(attachment.bucket, attachment.path, io)
            io.rewind
            zip_builder.add_file "#{ent_num}/#{attachment.attached_file_name}", io
          end
        end
      end
  end

end; end
