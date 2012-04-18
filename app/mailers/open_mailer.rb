class OpenMailer < ActionMailer::Base
  ATTACHMENT_LIMIT = 10.megabytes
  ATTACHMENT_TEXT = <<EOS
The attachments for this message were larger than the maximum system size.
Click <a href='_path_'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EOS

  default :from => "do-not-reply@chain.io"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.open_mailer.send_change.subject
  #
  def send_change(history,subscription,text_only)
    details = history.details_hash
    type = details[:type].nil? ? "Item" : details[:type]
    identifier = details[:identifier].nil? ? "[unknown]" : details[:identifier]
    @detail_hash = details
    if !text_only
      mail(:to => subscription.user.email, :subject => "#{type} #{identifier} changed.") do |format|
        format.html
      end
    else
      mail(:to => subscription.user.email, :subject => "#{type} #{identifier} changed. [txt]") do |format|
        format.text
      end
    end
  end
  
  def send_feedback(current_user,params,request)
    @user = current_user
    @params = params
    @request = request
    mail(:to => 'chainio-feedback@aspect9.com',
         :subject => "[chain.io User Feedback] #{current_user.full_name} - #{current_user.company.name} - #{Time.now}",
         :reply_to => current_user.email
        )
  end

  def send_password_reset(user)
    @user = user
    mail(:to => user.email, :subject => "[chain.io] Password Reset") do |format| 
      format.text
    end
  end

  def send_new_system_init(password)
    @pwd = password
    mail(:to => "admin@aspect9.com", :subject => "New System Initialization") do |format|
      format.text
    end
  end

  def send_comment(current_user,to_address,comment,link=nil)
    @user = current_user
    @comment = comment
    @link = link 
    mail(:to => to_address, :reply_to => current_user.email, :subject => "[chain.io] #{comment.subject}") do |format|
      format.text
    end
  end

  def send_search_result(to,search_name,attachment_name,file_path)
    attachment_saved = save_large_attachment(file_path, to)
    m = mail(:to => to,
      :subject => "[chain.io] #{search_name} Result",
      :from => 'do-not-reply@chain.io')
    m.postmark_attachments = {
      "Name"        => file_path.split('/').last,
      "Content"     => Base64.encode64(File.read(file_path)),
      "ContentType" => "application/octet-stream"
    } unless attachment_saved
    m
  end

  def send_uploaded_items(to,imported_file,data,current_user)
    @current_user = current_user
    data_to_send = [data].pack("m")
    data_file_path = File.join("/tmp", imported_file.attached_file_name)
    File.open(data_file_path, "w") { |f| f.write data_to_send } if data_to_send.length > ATTACHMENT_LIMIT
    attachment_saved = save_large_attachment(data_file_path, to)
    
    m = mail(:to=>to,
      :reply_to=>current_user.email,
      :subject => "[chain.io] #{CoreModule.find_by_class_name(imported_file.module_type).label} File Result")
    m.postmark_attachments = {
      "Name" => imported_file.attached_file_name,
      "Content" => data_to_send,
      "ContentType" => "application/octet-stream"
    } unless attachment_saved
    m
  end

  # Send a file that is currently on s3
  def send_s3_file current_user, to, cc, subject, body_text, bucket, s3_path, attachment_name=nil
    a_name = attachment_name.blank? ? s3_path.split('/').last : attachment_name
    t = OpenChain::S3.download_to_tempfile bucket, s3_path
    @body_text = ''
    attachment_saved = save_large_attachment(t.path, to)
    @user = current_user
    # Concatenate passed message with the text set when large file is saved
    # to S3 for direct download
    @body_text = body_text + @body_text
    m = mail(:to=>to, :cc=>cc, :reply_to=>current_user.email, :subject => subject)
    m.postmark_attachments = {
      "Name" => a_name,
      "Content" => Base64.encode64(File.read(t.path)),
      "ContentType"=> "application/octet-stream"
    } unless attachment_saved
    m
  end

  def send_message(message)
    @message = message
    @messages_url = ''
    if @message.user.host_with_port
      @messages_url = messages_url(:host => @message.user.host_with_port)
    end
    
    mail(:to => message.user.email, :subject => "[chain.io] New Message - #{message.subject}") do |format|
      format.html
    end
  end
  
#ERROR EMAILS
  def send_search_fail(to,search_name,error_message,ftp_server,ftp_username,ftp_subfolder)
    @search_name = search_name
    @error_message = error_message
    @ftp_server = ftp_server
    @ftp_username = ftp_username
    @ftp_subfolder = ftp_subfolder

    mail(:to=>to, :bcc=>"support@chain.io", :subject => "[chain.io] Search Transmission Failure") do |format|
      format.text
    end
  end

  def send_imported_file_process_fail imported_file, source="Not Specified" #source can be any object, if it is a user, the email will have the user's full name, else it will show source.to_s
    @imported_file = imported_file
    @source = source
    mail(:to=>"bug@aspect9.com",:subject =>"[chain.io Exception] - Imported File Error") do |format|
      format.text
    end
  end

  def send_custom_search_error(user, error, params)
    @user = user
    @error = error  
    @params = params
    mail(:to => "bug@aspect9.com", :subject => "[chain.io Exception] Search Failure") do |format|
      format.text
    end
  end

  #only Exception#log_me should use this.  Everything else should just call .log_me on the exception
  def send_generic_exception e, additional_messages=[], error_message=nil, backtrace=nil, attachment_paths=[]
    @exception = e
    @error_message = error_message ? error_message : e.message
    @backtrace = backtrace ? backtrace : e.backtrace
    @backtrace = [] unless @backtrace
    @additional_messages = additional_messages
    attachment_files = []
    attachment_paths.each do |ap|
      attachment_files << File.open(ap) if File.exists?(ap)
    end
    mail(:to=>"bug@aspect9.com",
      :subject =>"[chain.io Exception] - #{@error_message}",
      :postmark_attachments => attachment_files) do |format|
      format.text
    end
  end

  #send survey response invite
  def send_survey_invite survey_response
    survey = survey_response.survey
    @body_textile = survey.email_body
    @link_addr = "http://#{MasterSetup.get.request_host}/survey_responses/#{survey_response.id}"
    mail(:to=>survey_response.user.email,:subject=>survey.email_subject) do |format|
      format.html
    end
  end

  #send survey update notification
  def send_survey_update survey_response
    @link_addr = "http://#{MasterSetup.get.request_host}/surveys/#{survey_response.survey.id}"
    to = survey_response.survey.survey_subscriptions.map {|ss| ss.user.email}.join(',')
    mail(:to=>to, :subject=>"Survey updated") do |format|
      format.html
    end
  end

  def send_support_ticket_to_agent support_ticket
    to = support_ticket.agent ? support_ticket.agent.email : "support@vandegriftinc.com"
    @ticket = support_ticket
    mail(:to=>to,:subject=>"[Support Ticket Update]: #{support_ticket.subject}") do |format|
      format.html
    end
  end

  def send_support_ticket_to_requestor support_ticket
    @ticket = support_ticket
    mail(:to=>support_ticket.requestor.email,:subject=>"[Support Ticket Update]: #{support_ticket.subject}") do |format|
      format.html
    end
  end

  private
  def sanitize_filename(filename)
    filename.strip.tap do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.sub! /\A.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore
      # or periods with underscore
      name.gsub! /[^\w\.\-]/, '_'
    end
  end

  def save_large_attachment(file_path, registered_emails)
    if File.exist?(file_path) && File.size(file_path) > ATTACHMENT_LIMIT
      ActionMailer::Base.default_url_options[:host] = MasterSetup.get.request_host

      email_attachment = EmailAttachment.create!(:email => registered_emails)
      email_attachment.attachment = Attachment.new(:attachable => email_attachment)
      email_attachment.attachment.attached = File.open(file_path)
      email_attachment.attachment.save
      email_attachment.save

      @body_text = ATTACHMENT_TEXT.gsub(/_path_/, email_attachments_show_url(email_attachment))
      return true
    end
    false
  end
end
