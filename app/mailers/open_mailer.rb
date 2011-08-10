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
    attachments[attachment_name] = File.read file_path
    mail(:to => to, :subject => "[chain.io] #{search_name} Result") do |format|
      format.text
    end
  end

  def send_uploaded_items(to,imported_file,data,current_user)
    attachments[imported_file.attached_file_name] = data
    @current_user = current_user
    mail(:to=>to, :reply_to=>current_user.email, :subject => "[chain.io] #{CoreModule.find_by_class_name(imported_file.module_type).label} File Result") do |format|
      format.text
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
    attachment_paths.each do |ap|
      attachments[File.basename(ap)] = File.read(ap) if File.exists? ap
    end
    mail(:to=>"bug@aspect9.com",:subject =>"[chain.io Exception] - #{@error_message}") do |format|
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
