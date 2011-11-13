class OpenMailer < ActionMailer::Base
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
    m = mail(:to => to,
      :subject => "[chain.io] #{search_name} Result",
      :from => 'do-not-reply@chain.io')
    m.postmark_attachments = {
      "Name"        => file_path.split('/').last,
      "Content"     => Base64.encode64(File.read(file_path)),
      "ContentType" => "application/octet-stream"
    }
    m
  end

  def send_uploaded_items(to,imported_file,data,current_user)
    @current_user = current_user
    attachment = {"Name" => imported_file.attached_file_name,
      "Content" => [data].pack("m"),
      "ContentType" => "application/octet-stream"}
    
    m = mail(:to=>to,
      :reply_to=>current_user.email,
      :subject => "[chain.io] #{CoreModule.find_by_class_name(imported_file.module_type).label} File Result")
    m.postmark_attachments = attachment
    m
  end

  # Send a file that is currently on s3
  def send_s3_file current_user, to, cc, subject, body_text, bucket, s3_path, attachment_name=nil
    a_name = attachment_name.blank? ? s3_path.split('/').last : attachment_name
    t = OpenChain::S3.download_to_tempfile bucket, s3_path
    attachment = {"Name" => a_name, "Content" => Base64.encode64(File.read(t.path)),"ContentType"=> "application/octet-stream"}
    @user = current_user
    @body_text = body_text
    m = mail(:to=>to, :cc=>cc, :reply_to=>current_user.email, :subject => subject)
    m.postmark_attachments = attachment
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
end
