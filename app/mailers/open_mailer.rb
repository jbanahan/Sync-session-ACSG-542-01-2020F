class OpenMailer < ActionMailer::Base
  include AbstractController::Callbacks # This can be removed when migrating to rails 4

  after_filter :handle_sent_email #includes handling for :redirect_to_developer, :send_generic_exception

  ATTACHMENT_LIMIT ||= 10.megabytes
  ATTACHMENT_TEXT ||= <<EOS
An attachment named '_filename_' for this message was larger than the maximum system size.
Click <a href='_path_'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EOS

  default :from => "do-not-reply@vfitrack.net"
  LINK_PROTOCOL ||= Rails.env.production? ? "https" : "http"
  BUG_EMAIL = "bug@vandegriftinc.com"

  #send a simple plain text email
  def send_simple_text to, subject, body

    @body_content = body
    mail(:to=>to,:subject=>subject) do |format|
      format.text
    end
  end

  #send a very simple HTML email (attachments are expected to answer as File objects or paths )
  def send_simple_html to, subject, body, file_attachments = [], mail_options = {}
    @body_content = body
    pm_attachments = []
    opts = {to: explode_group_and_mailing_lists(to, "TO"), subject: subject}.merge mail_options
    local_attachments = process_attachments(file_attachments, opts[:to])
    suppressed = opts.delete :suppressed

    m = mail(opts) do |format|
      format.html
    end

    local_attachments.each {|name, content| m.attachments[name] = content}
    set_suppressed_flag(m) if suppressed
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

  def send_registration_request(email_address, first_name, last_name, company, customer_number, contact, system_code)
    @email = email_address
    @first_name = first_name
    @last_name = last_name
    @company = company
    @customer_number = customer_number
    @contact = contact
    @system_code = system_code

    mail(:to => "support@vandegriftinc.com", :subject => "Registration Request (#{system_code})")
  end

  def send_feedback(user, message, current_page)
    @user = user
    @message = message
    @current_page = current_page
    mail(:to => 'support@vandegriftinc.com',
         :subject => "[VFI Track] [User Feedback] #{user.company.name} - #{user.full_name}",
         :reply_to => user.email
        )
  end

  def send_password_reset(user)
    @user = user
    @reset_url = edit_password_reset_url(@user.confirmation_token, host: emailer_host(user))
    mail(:to => user.email, :subject => "[VFI Track] Password Reset") do |format|
      format.html
    end
  end

  def send_new_system_init(password)
    @pwd = password
    mail(:to => BUG_EMAIL, :subject => "New System Initialization") do |format|
      format.text
    end
  end

  def send_comment(current_user,to_address,comment,link=nil)
    @user = current_user
    @comment = comment
    @link = link
    mail(:to => to_address, :reply_to => current_user.email, :subject => "[VFI Track] #{comment.subject}")
  end

  def send_search_result(to, search_name, attachment_name, file_path, user)
    @user = user
    attachment_saved = save_large_attachment(file_path, to)
    m = mail(:to => explode_group_and_mailing_lists(to, "TO"),
      :subject => "[VFI Track] #{search_name} Result",
      :from => 'do-not-reply@vfitrack.net')
    unless attachment_saved
      m.attachments[attachment_name] = create_attachment file_path
    end
    m
  end

  def send_search_result_manually(to, subject, body, file_path, current_user)
    @user = current_user
    attachment_saved = save_large_attachment(file_path, to)
    @body_text = body
    m = mail(:to => explode_group_and_mailing_lists(to, "TO"),
      :reply_to => @user.email,
      :subject => subject)
    unless attachment_saved
      m.attachments[attachment_filename(file_path)] = create_attachment file_path
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
      :subject => "[VFI Track] #{CoreModule.find_by_class_name(imported_file.module_type).label} File Result")

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
    email_text = [body_text]
    large_attachment = false
    save_large_attachment(t.path, to) do |large_file_attachment, attachment_text|
      if large_file_attachment
        large_attachment = true
      end

      if !attachment_text.blank?
        # Concatenate passed message with the text set when large file is saved
        # to S3 for direct download
        email_text << "<br><br>".html_safe
        email_text << attachment_text
      end
    end
    @user = current_user
    @body_text = email_text

    m = mail(:to=>to, :reply_to=>current_user.email, :subject => subject)
    # Postmark does not handle blank CC / BCC fields any longer without erroring (dumb)
    m.cc = cc unless cc.blank?
    m.attachments[a_name] = create_attachment(t) unless large_attachment

    m
  end

  def send_message(message)
    @message = message
    @messages_url = messages_url(:host => emailer_host(@message.user))

    mail(:to => message.user.email, :subject => "[VFI Track] New Message - #{message.subject}") do |format|
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

    mail(:to=>to, :bcc=>"support@vandegriftinc.com", :subject => "[VFI Track] Search Transmission Failure") do |format|
      format.text
    end
  end

  def send_search_bad_email(to, search, error_message)
    @search_name = search.name
    @search_url = Rails.application.routes.url_helpers.advanced_search_url(host: MasterSetup.get.request_host, id: search.id, protocol: (Rails.env.development? ? "http" : "https"))
    @error_message = error_message

    mail(:to=>to, :subject => "[VFI Track] Search Transmission Failure") do |format|
      format.html
    end
  end

  def send_imported_file_process_fail imported_file, source="Not Specified" #source can be any object, if it is a user, the email will have the user's full name, else it will show source.to_s
    @imported_file = imported_file
    @source = source
    mail(:to=>"bug@vandegriftinc.com",:subject =>"[VFI Track Exception] - Imported File Error") do |format|
      format.text
    end
  end

  def send_custom_search_error(user, error, params)
    @user = user
    @error = error
    @params = params
    mail(:to => "bug@vandegriftinc.com", :subject => "[VFI Track Exception] Search Failure") do |format|
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
      if save_large_attachment ap, 'bug@vandegriftinc.com'
        @additional_messages << @body_text
      else
        local_attachments[attachment_filename(ap)] = create_attachment ap
      end
    end
    m = mail(:to=>"bug@vandegriftinc.com", :subject =>"[VFI Track Exception] - #{@error_message}"[0..99]) do |format|
      format.text
    end

    local_attachments.each {|name, content| m.attachments[name] = content}

    m
  end

  def send_ack_file_exception recipient, error_messages, attached_file, file_name, sync_code, subject = "[VFI Track] Ack File Processing Error"
    @error_messages = error_messages
    @sync_code = sync_code
    mail_opts = {to: explode_group_and_mailing_lists(recipient, "TO"), subject: subject}
    m = mail(mail_opts)
    m.attachments[file_name] = create_attachment attached_file
    m
  end

  def send_survey_expiration_reminder to, expired_survey, expired_responses
    @expired_survey = expired_survey
    @expired_responses = expired_responses
    @link_addr = "#{LINK_PROTOCOL}://#{MasterSetup.get.request_host}/surveys/#{expired_survey.id}"
    mail(to: to, subject: "Survey \"#{@expired_survey.name}\" has #{expired_responses.count} expired survey(s).") do |format|
      format.html
    end
  end

  #send survey response invite
  def send_survey_invite survey_response
    survey = survey_response.survey
    @subtitle = survey_response.subtitle
    @body_textile = survey.email_body
    @link_addr = "#{LINK_PROTOCOL}://#{MasterSetup.get.request_host}/survey_responses/#{survey_response.id}"
    email_subject = survey.email_subject + (@subtitle.blank? ? "" : " - #{@subtitle}")
    to = [survey_response.user.try(:email)]
    to << survey_response.group
    to = explode_group_and_mailing_lists to.compact, "TO"
    mail(:to=>to,:subject=>email_subject) do |format|
      format.html
    end
  end

  def send_survey_reminder survey_response, to, subject, body
    link_addr = "#{LINK_PROTOCOL}://#{MasterSetup.get.request_host}/survey_responses/#{survey_response.id}"
    @body_content = "<p>#{ERB::Util.html_escape(body).gsub("\n", "<br>")}</p><p>#{link_addr}</p>".html_safe
    @attachment_messages = []
    mail(:to=>to, :subject=>subject) do |format|
      format.html { render 'send_simple_html' }
    end
  end

  #send survey update notification
  def send_survey_subscription_update survey_response, response_updates, survey_subscriptions, corrective_action_plan = false
    @cap_mode = corrective_action_plan
    @link_addr = "#{LINK_PROTOCOL}://#{MasterSetup.get.request_host}/survey_responses/#{survey_response.id}"
    @updated_by = response_updates.collect {|u| u.user.full_name}
    @survey_title = get_survey_title survey_response

    to = survey_subscriptions.map {|ss| ss.user.email}.join(',')
    mail(:to=>to, :subject=>"Survey Updated") do |format|
      format.html
    end
  end

  #send survey update to survey response assigned user
  def send_survey_user_update survey_response, corrective_action_plan = false
    @cap_mode = corrective_action_plan
    @link_addr = "#{LINK_PROTOCOL}://#{MasterSetup.get.request_host}/surveys/#{survey_response.survey.id}"

    to = [survey_response.user.try(:email)]
    to << survey_response.group
    to = explode_group_and_mailing_lists to.compact, "TO"
    mail(:to=>to, :subject=>"#{survey_response.survey.name} - Updated") do |format|
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

  def send_support_request_to_helpdesk to, support_request
    @request = support_request
    @system_code = MasterSetup.get.system_code
    mail(:to=>to, :reply_to => support_request.user.email, :subject=>"[Support Request ##{@request.ticket_number} (#{@system_code})]") do |format|
      format.html
    end
  end

  def send_tariff_set_change_notification tariff_set, user
    @ts = tariff_set
    mail(to:user.email,subject:"[VFI Track] Tariff Update - #{tariff_set.country.name}") do |format|
      format.text
    end
  end

  def send_invite user, temporary_password
    @user = user
    @temporary_password = temporary_password
    @login_url = url_for(host: MasterSetup.get.request_host, controller: 'user_sessions', action: 'new', protocol: LINK_PROTOCOL)

    mail(to:user.email,subject:"[VFI Track] Welcome, #{user.first_name} #{user.last_name}!") do |format|
      format.html
    end
  end

  def send_high_priority_tasks(user, tasks) #tasks is a list of ProjectDeliverable objects
    @user = user
    @tasks = tasks
    @lp = LINK_PROTOCOL
    time = Time.now
    mail(to: user.email, subject: "[VFI Track] Task Priorities - #{time.strftime('%m/%d/%y')}") do |format|
      format.html
    end
  end

  def auto_send_attachments to, subject, body, file_attachments, sender_name, sender_email
    @body_content = ERB::Util.html_escape(body).gsub("\n", "<br>").html_safe
    @attachment_messages = []
    @sender_name = sender_name
    @sender_email = sender_email
    pm_attachments = []

    file_attachments = ((file_attachments.is_a? Enumerable) ? file_attachments : [file_attachments])
    local_attachments = {}
    file_attachments.each do |file|

      save_large_attachment(file, to) do |email_attachment, attachment_text|
        if email_attachment
          @attachment_messages << attachment_text
        else
          local_attachments[attachment_filename(file)] = create_attachment(file)
        end
      end
    end

    m = mail(:to=>to, :reply_to => sender_email, :subject=>subject) do |format|
      format.html
    end

    local_attachments.each {|name, content| m.attachments[name] = content}
    m
  end

  def send_high_priority_tasks(user, tasks) #tasks is a list of ProjectDeliverable objects
    @user = user
    @tasks = tasks
    @lp = LINK_PROTOCOL
    time = Time.now
    mail(to: user.email, subject: "[VFI Track] Task Priorities - #{time.strftime('%m/%d/%y')}") do |format|
      format.html
    end
  end

  def send_crocs_manual_bill_reminder invoice_number
    @invoice_number = invoice_number
    mail(to: "crocs-manual-billing@vandegriftinc.com", subject: "[VFI Track] Crocs Invoice # #{invoice_number}") do |fmt|
      fmt.html
    end
  end

  def log_email suppressed=false
    # Note: This method is stubbed out in testing unless you specifically tag your testing spec with "email_log: true"
    attachment_list = []
    message.attachments.each { |att| attachment_list << message_att_to_standard_att(att) } unless message.attachments.empty?
    # Message.to/etc are all actually Mail::AddressContainer, so we have to convert them to just a string before saving them
    # Message.body is much more complex and also cannot be directly saved to the database, the body text must be extracted first.
    SentEmail.create!(email_subject: message.subject, email_to: extract_email_addresses(message.to), email_cc: extract_email_addresses(message.cc),
                      email_bcc: extract_email_addresses(message.bcc), email_from: extract_email_addresses(message.from),
                      email_reply_to: extract_email_addresses(message.reply_to), email_date: Time.zone.now, email_body: extract_email_body(message.body),
                      attachments: attachment_list, suppressed: suppressed)
  end


  def send_kewill_imaging_error email_to, errors, file_type, filename, file
    @errors = errors
    @filename = filename
    @file_type = file_type.blank? ? "Unknown" : file_type
    # file may be nil if it's too large to be processed
    @blacklisted_extension = File.extname(file) if file && extension_blacklisted?(file)
    local_attachments = file ? process_attachments(file, email_to) : []

    m = mail(to: email_to, subject: "[VFI Track] Failed to load file #{filename}") do |format|
      format.html
    end

    local_attachments.each {|name, content| m.attachments[name] = content}
    m
  end

  private

    #http://developer.postmarkapp.com/developer-send-api.html#attachments
    def extension_blacklisted? file 
      [".vbs", ".exe", ".bin", ".bat", ".chm", ".com", ".cpl", 
       ".crt", ".hlp", ".hta", ".inf", ".ins", ".isp", ".jse", 
       ".lnk", ".mdb", ".pcd", ".pif", ".reg", ".scr", ".sct", 
       ".shs", ".vbe", ".vba", ".wsf", ".wsh", ".wsl", ".msc", 
       ".msi", ".msp", ".mst"].include? File.extname(file)
    end

    def extract_email_addresses list
      emails = list
      if list && list.respond_to?(:select)
        emails = list.select {|m| !m.nil? && !m.blank? }.join(", ")
      end
      emails
    end

    def extract_email_body body
      # This seems to render the body out in the format that you would expect it to, and ignores attachment body parts.
      body ? body.decoded : nil
    end

    def message_att_to_standard_att message_attachment
      filename_ext = File.extname(message_attachment.filename)
      filename_without_ext = File.basename(message_attachment.filename, ".*")

      Tempfile.open([filename_without_ext, filename_ext]) do |temp|
        Attachment.add_original_filename_method(temp, message_attachment.filename)
        temp.binmode
        temp << message_attachment.read
        temp.flush
        temp.rewind

        standard_att = Attachment.new
        standard_att.attached = temp
        standard_att.save!
        standard_att
      end
    end

    def process_attachments file_attachments, email_to
      # Something funky happens with the mail if you use the 'attachments' global prior to creating a mail object
      # instead of the mail.attachments attribute.  The mail content ends up being untestable for some reason I think
      # is related to messed up/out of order MIME hierarchies in the email.
      local_attachments = {}
      @attachment_messages = []

      approved_attachments = Array.wrap(file_attachments).reject{ |f| extension_blacklisted? f }      
      approved_attachments.each do |file|

        save_large_attachment(file, email_to) do |email_attachment, attachment_text|
          if email_attachment
            @attachment_messages << attachment_text
          else

            filename = attachment_filename(file)
            local_attachments[filename] = create_attachment(file)
          end
        end
      end

      local_attachments
    end

    def attachment_filename file
      # Use original_filename if the object answers to the method, else use the path's basename.
      ((file.respond_to?(:original_filename)) ? file.original_filename : File.basename((file.respond_to?(:path) ? file.path : file)))
    end

    def save_large_attachment(file, registered_emails)
      email_attachment = nil
      attachment_text = nil
      if large_attachment? file
        ActionMailer::Base.default_url_options[:host] = MasterSetup.get.request_host
        email_attachment = EmailAttachment.create!(:email => Array.wrap(registered_emails).join(","))
        email_attachment.attachment = Attachment.new(:attachable => email_attachment)
        # Allow passing file objects here as well, not just paths to a file.
        # This also allows us to implement an original_filename method on the file object to utilize the paperclip
        # attachment naming.
        email_attachment.attachment.attached = (file.is_a?(String) ? File.open(file) : file)
        email_attachment.attachment.save
        email_attachment.save

        attachment_text = ATTACHMENT_TEXT.gsub(/_path_/, email_attachments_show_url(email_attachment)).gsub(/_filename_/, email_attachment.attachment.attached_file_name)
        attachment_text = attachment_text.html_safe
      elsif blank_attachment? file
        ActionMailer::Base.default_url_options[:host] = MasterSetup.get.request_host

        # PostMark will raise exceptions if this is exactly nil, but a blank string is acceptable
        email_attachment = ""
        attachment_text = "* The attachment '#{attachment_filename(file)}' was excluded because it was empty."
        attachment_text = attachment_text.html_safe
      end

      if block_given?
        yield email_attachment, attachment_text
      else
        @body_text = attachment_text if attachment_text
        return (attachment_text.nil? ? false : true)
      end
    end

    def user_management_email?
      return action_name == "send_password_reset" || action_name == "send_invite"
    end

    def handle_sent_email
      if action_name == "send_generic_exception"
        # We never want to suppress exception emails, otherwise issues when testing could get missed very easily
        log_email false
        # In dev, we don't actually want to email errors...we're actually going to use the logger instead to render them 
        redirect_to_developer 
      else
        # Don't suppress emails if they're for user management. Otherwise surpress them if they're marked or all emails are suppressed
        suppress_email = !user_management_email? && ( message.respond_to?(:suppressed) || suppress_all_emails? )
        sent_email = log_email suppress_email
        if suppress_email
          message.delivery_method NoOpMailer
        else
          message.delivery_method(LoggingMailerProxy, message.delivery_method.settings.merge({original_delivery_method: message.delivery_method, sent_email: sent_email}))
        end
      end      
    end

    def set_suppressed_flag message
      message.define_singleton_method(:suppressed) { true } 
    end

    def suppress_all_emails?
      # We don't want to suppress emails in test env, since the test mailer is used to capture emails for test cases to introspect
      !test_env? && !MasterSetup.email_enabled?
    end

    require 'mail/check_delivery_params'
    class NoOpMailer
      attr_accessor :settings

      def initialize settings
        @settings = settings
      end

      def deliver!(mail)
        # We'll still want to check the mail for validity so that errors raised normally on an email would be 
        # Below is what the standard mailer does
        Mail::CheckDeliveryParams.check(mail)
      end
    end

    # This class exists soley as a means of sitting between the "real" mailer and our code, so that if an error occurs when a message is delivered (.ie deliver! is called)
    # that we log that error against the sent_email log object that was created for when the mail object was actually built.
    #
    # It also allows for swallowing some errors that occur, since there's no point in bubbling some of them up and potentially causing a delayed job to re-run.
    class LoggingMailerProxy
      attr_accessor :original_delivery_method, :sent_email, :settings

      def initialize settings
        @settings = settings
        @original_delivery_method = settings.delete :original_delivery_method
        @sent_email = settings.delete :sent_email
      end

      def deliver! mail
        original_delivery_method.deliver! mail
      rescue Exception => e
        handle_email_error(e, mail, original_delivery_method, sent_email)
        nil
      end

      def handle_email_error error, mail, delivery_method, sent_email
        sent_email.update_attributes! delivery_error: error.message
        raise error unless swallow_error?(error)
      end

      def swallow_error? error
        # There might be more conditions we want to actually swallow email errors fore
        # but for now, just swallow them when there's an InvalidMessageError, which occurs
        # whenever a recipient is referenced that is inactive.  There's no use re-raising this
        # error, since the email will never actually go through (unless user is reactivated and stays that way)
        if error.is_a?(Postmark::InvalidMessageError)
          return true
        else
          return false
        end
      end
    end

    # Broken out for ease of mocking without forcing Rails.env to return bad values in test
    def test_env?
      Rails.env.test?
    end

    def development_env?
      Rails.env.development?
    end
    
    def redirect_to_developer
      if development_env?
        headers['X-ORIGINAL-TO'] = message.to.blank? ? 'blank' : message.to.join(", ")
        headers['X-ORIGINAL-CC'] = message.cc.blank? ? 'blank' : message.cc.join(", ")
        headers['X-ORIGINAL-BCC'] = message.bcc.blank? ? 'blank' : message.bcc.join(", ")
        #Postmark doesn't like blank strings, nils, or blank lists...
        message.cc = [""]
        message.bcc = [""]

        message.to = [MasterSetup.config_value("exception_email_to", default: "you-must-set-exception_email_to-in-vfitrack-config@vandegriftinc.com")]
      end
    end

    def explode_group_and_mailing_lists list, list_type
      new_list = []
      group_codes = []
      mailing_list_codes = []
      Array.wrap(list).each do |email_address|
        if email_address.is_a? Group
          group_codes << email_address.system_code
          emails = email_address.user_emails
          new_list.push(*emails) if emails.length > 0
        elsif email_address.is_a? MailingList
          mailing_list_codes << email_address.system_code
          emails = email_address.split_emails
          new_list.push(*emails) if emails.length > 0
        else
          new_list << email_address
        end
      end
      # Track the groups being sent to under the covers to easily back-trace actual emails to distinct
      # groups
      headers["X-ORIGINAL-GROUP-#{list_type}"] = group_codes.join(", ") unless group_codes.blank?
      new_list.blank? ? nil : new_list.flatten
    end

    def large_attachment? file
      file_exists?(file) && file_size(file) > ATTACHMENT_LIMIT
    end

    def blank_attachment? file
      file_size(file) == 0
    end

    def file_size file
      if file.is_a?(String)
        File.size(file).to_i
      elsif file.respond_to?(:to_path)
        File.size(file.to_path.to_s).to_i
      else
        File.size(file).to_i
      end
    end

    def file_exists? file
      if file.is_a?(String)
        File.exist? file
      elsif file.respond_to?(:to_path)
        File.exist? file.to_path.to_s
      else
        File.exist? file
      end
    end

    def create_attachment data, data_is_file = true
      if data_is_file
        data = IO.read((data.respond_to?(:path) ? data.path : (data.respond_to?(:to_path) ? data.to_path.to_s : data)), mode: "rb")
      end
      # When using the native Rails mail attachments you no longer have to base64 encode the data, the
      # postmark library handles that behind the scenes for us now.
      {content: data,
        mime_type: "application/octet-stream"}
    end

    def emailer_host user
      user.host_with_port.blank? ? MasterSetup.get.request_host : user.host_with_port
    end

    def get_survey_title survey_response
      survey_title = "\"#{survey_response.survey_name}\""
      if !survey_response.subtitle.to_s.empty?
        survey_title = survey_title + " subtitled \"#{survey_response.subtitle}\""
      end
      survey_title
    end

end
