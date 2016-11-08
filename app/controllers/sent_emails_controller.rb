class SentEmailsController < ApplicationController

  SEARCH_PARAMS = {
    'to' => {:field => 'email_to', :label=> 'To'},
    'from' => {:field => 'email_from', :label => "From"},
    'subject' => {:field => 'email_subject', :label => 'Subject'},
    'body' => {:field => 'email_body', :label => "Body"},
    'date' => {:field => 'email_date', :label => "Date"},
  }

  def index
    admin_secure {
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'subject', 'date', 'd')
      respond_to do |format|
          format.html {
              @sent_emails = s.paginate(:per_page => 20, :page => params[:page])
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
      render :inline => email.email_body.to_s
    }
  end
  
  private 

  def secure
    SentEmail.find_can_view(current_user)
  end

end

