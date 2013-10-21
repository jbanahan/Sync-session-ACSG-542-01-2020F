class OpenMailer < ActionMailer::Base
  ATTACHMENT_LIMIT = 10.megabytes
  ATTACHMENT_TEXT = <<EOS
An attachment named '_filename_' for this message was larger than the maximum system size.
Click <a href='_path_'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EOS

  default :from => "do-not-reply@chain.io"

  #send a simple plain text email
  def send_simple_text to, subject, body

    @body_content = body
    mail(:to=>to,:subject=>subject) do |format|
      format.text
    end
  end

  #send a very simple HTML email (attachments are expected to answer as File objects or paths )
  def send_simple_html to, subject, body, file_attachments = []
    @body_content = body
    @attachment_messages = []

    pm_attachments = []

    file_attachments = ((file_attachments.is_a? Enumerable) ? file_attachments : [file_attachments])
    # Something funky happens with the mail if you use the 'attachments' global prior to creating a mail object
    # instead of the mail.attachments attribute.  The mail content ends up being untestable for some reason I think
    # is related to messed up/out of order MIME hierarchies in the email.
    local_attachments = {}
    file_attachments.each do |file|
      
      save_large_attachment(file, to) do |email_attachment, attachment_text|
        if email_attachment
          @attachment_messages << attachment_text
        else
          # Use original_filename if the object answers to the method, else use the path's basename.
          filename = ((file.respond_to?(:original_filename)) ? file.original_filename : File.basename((file.respond_to?(:path) ? file.path : file)))
          local_attachments[filename] = create_attachment(file)
        end
      end
      
    end

    m = mail(:to=>to,:subject=>subject) do |format|
      format.html
    end

    local_attachments.each {|name, content| m.attachments[name] = content}
    m
  end

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

  def send_password_reset(user, expires_at)
    @user = user
    # Make sure the expiration time is presented in the user's timezone
    @expires_at = expires_at.in_time_zone(user.time_zone) rescue expires_at

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
    unless attachment_saved
      m.attachments[File.basename(file_path)] = create_attachment file_path
    end
    m
  end

  def send_uploaded_items(to,imported_file,data,current_user)
    @current_user = current_user
    data_file_path = Tempfile.new([File.basename(imported_file.attached_file_name, ".*"), File.extname(imported_file.attached_file_name)])
    data_file_path.binmode
    Attachment.add_original_filename_method data_file_path
    data_file_path.original_filename = imported_file.attached_file_name
    data_file_path.write data
    data_file_path.rewind

    attachment_saved = save_large_attachment(data_file_path, to)

    m = mail(:to=>to,
      :reply_to=>current_user.email,
      :subject => "[chain.io] #{CoreModule.find_by_class_name(imported_file.module_type).label} File Result")

    unless attachment_saved
      m.attachments[imported_file.attached_file_name] = create_attachment data_file_path
    end

    m
  ensure
    data_file_path.unlink if data_file_path
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
    m = mail(:to=>to, :reply_to=>current_user.email, :subject => subject)
    # Postmark does not handle blank CC / BCC fields any longer without erroring (dumb)
    m.cc = cc unless cc.blank?

    unless attachment_saved
      m.attachments[a_name] = create_attachment(t)
    end
    m
  end

  def send_message(message)
    @message = message
    host = @message.user.host_with_port ? @message.user.host_with_port : MasterSetup.get.request_host
    @messages_url = messages_url(:host => host)
    
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
    @additional_messages = additional_messages.nil? ? [] : additional_messages
    @time = Time.now.in_time_zone("Eastern Time (US & Canada)").inspect
    @hostname = Socket.gethostname
    @process_id = Process.pid
    local_attachments = {}
    attachment_paths.each do |ap|
      if save_large_attachment ap, 'bug@aspect9.com' 
        @additional_messages << @body_text
      else
        local_attachments[File.basename(ap)] = create_attachment ap
      end
    end  
    m = mail(:to=>"bug@aspect9.com", :subject =>"[chain.io Exception] - #{@error_message}"[0..99]) do |format|
      format.text
    end

    local_attachments.each {|name, content| m.attachments[name] = content}

    m
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
  def send_survey_subscription_update survey_response, corrective_action_plan = false
    @cap_mode = corrective_action_plan
    @link_addr = "http://#{MasterSetup.get.request_host}/surveys/#{survey_response.survey.id}"
    to = survey_response.survey.survey_subscriptions.map {|ss| ss.user.email}.join(',')
    mail(:to=>to, :subject=>"Survey Updated") do |format|
      format.html
    end
  end

  #send survey update to survey response assigned user
  def send_survey_user_update survey_response, corrective_action_plan = false
    @cap_mode = corrective_action_plan
    @link_addr = "http://#{MasterSetup.get.request_host}/surveys/#{survey_response.survey.id}"
    mail(:to=>survey_response.user.email, :subject=>"#{survey_response.survey.name} - Updated") do |format|
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

  def send_tariff_set_change_notification tariff_set, user
    @ts = tariff_set
    mail(to:user.email,subject:"[chain.io] Tariff Update - #{tariff_set.country.name}") do |format|
      format.text
    end
  end

  def send_invite user, temporary_password
    @user = user
    @temporary_password = temporary_password
    @login_url = url_for(host: MasterSetup.get.request_host, controller: 'user_sessions', action: 'new', protocol: 'https')

    mail(to:user.email,subject:"[chain.io] Welcome, #{user.first_name} #{user.last_name}!") do |format|
      format.html
    end
  end

  private

    def save_large_attachment(file, registered_emails)
      email_attachment = nil
      large_attachment_text = nil

      if large_attachment? file
        ActionMailer::Base.default_url_options[:host] = MasterSetup.get.request_host

        email_attachment = EmailAttachment.create!(:email => registered_emails)
        email_attachment.attachment = Attachment.new(:attachable => email_attachment)
        # Allow passing file objects here as well, not just paths to a file.
        # This also allows us to implement an original_filename method on the file object to utilize the paperclip
        # attachment naming.
        email_attachment.attachment.attached = (file.is_a?(String) ? File.open(file) : file)
        email_attachment.attachment.save
        email_attachment.save

        large_attachment_text = ATTACHMENT_TEXT.gsub(/_path_/, email_attachments_show_url(email_attachment)).gsub(/_filename_/, email_attachment.attachment.attached_file_name)
        large_attachment_text = large_attachment_text.html_safe
      end

      if block_given?
        yield email_attachment, large_attachment_text
      else
        @body_text = large_attachment_text if large_attachment_text
        return (large_attachment_text.nil? ? false : true)
      end
    end

    def large_attachment? file
      File.exist?(file) && File.size(file) > ATTACHMENT_LIMIT
    end

    def create_attachment data, data_is_file = true
      if data_is_file
        data = File.open((data.respond_to?(:path) ? data.path : data), "rb") {|io| io.read}
      end
      # When using the native Rails mail attachments you no longer have to base64 encode the data, the 
      # postmark library handles that behind the scenes for us now.
      {content: data,
        mime_type: "application/octet-stream"}
    end
end
