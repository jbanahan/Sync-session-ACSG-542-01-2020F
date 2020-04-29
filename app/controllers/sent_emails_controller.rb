class SentEmailsController < ApplicationController

  SEARCH_PARAMS = {
    'to' => {:field => 'email_to', :label=> 'To'},
    'from' => {:field => 'email_from', :label => "From"},
    'subject' => {:field => 'email_subject', :label => 'Subject'},
    'body' => {:field => 'email_body', :label => "Body"},
    'date' => {:field => 'email_date', :label => "Date"},
    'suppressed' => {:field => 'suppressed', :label => "Suppressed"},
    'delivery_error' => {field: "length(delivery_error) > 0", label: "Delivery Error", datatype: :boolean}
  }

  def set_page_title
    @page_title ||= 'Sent Emails'
  end

  def index
    admin_secure {
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'subject', 'date', 'd')
      # No field has been selected...ie it's the initial page load
      if params[:f1].blank?
        s = s.where("created_at > ?", Time.zone.now.beginning_of_day)
        @default_display = "By default, only emails sent today are displayed when no search fields are utilized."
      end
      respond_to do |format|
          format.html {
              @sent_emails = s.paginate(:per_page => 40, :page => params[:page])
              render :layout => 'one_col'
          }
      end
    }
  end

  def show
    admin_secure {
      @sent_email = SentEmail.find(params[:id])
      respond_to do |format|
        format.html # show.html.erb
      end
    }
  end

  def body
    # In order to actually render the email's content on the page we're using an iframe to render it
    # with it's src pointing to this method
    admin_secure {
      email = SentEmail.find(params[:id])
      # While the following is called out by brakeman as an XSS, the source of the data is not from user input and the
      # data returned here is viewed on the page in an iframe.  I'm marking this as safe since I do not see a path to exploitation
      # via this action.
      render :inline => email.email_body.to_s
    }
  end

  private

  def secure
    SentEmail.find_can_view(current_user)
  end

end

