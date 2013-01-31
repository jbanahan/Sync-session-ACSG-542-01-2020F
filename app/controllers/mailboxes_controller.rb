class MailboxesController < ApplicationController
  def index
    respond_to do |format|
      format.html {render :layout=>'one_col'}
      format.json {
        r = []
        current_user.mailboxes.each do |m|
          h = {'id'=>m.id,'name'=>m.name,'archived'=>[],'not_archived'=>[]}
          load_assignment_counts m.assignment_breakdown(false), h['not_archived']
          load_assignment_counts m.assignment_breakdown(true), h['archived']
          r << h
        end
        render :json=>{'mailboxes'=>r}.to_json
      } 
    end
  end
  def show
    r = {}
    m = Mailbox.find params[:id]
    if m.can_view? current_user
      users = []
      r['id'] = m.id
      r['name'] = m.name
      r['emails'] = []
      emails = m.emails
      if params[:assigned_to] == '0'
        emails = emails.where(:assigned_to_id=>nil)
        r['selected_user'] = {'id'=>0,'full_name'=>'Not Assigned'}
      elsif params[:assigned_to] 
        sel_u = User.find params[:assigned_to]
        emails = emails.where(:assigned_to_id=>sel_u.id)
        r['selected_user'] = {'id'=>sel_u.id,'full_name'=>sel_u.full_name}
      end

      #filter out by the archive status
      if params[:archived].blank?
        emails = emails.not_archived
        r['archived'] = false
      else
        emails = emails.archived
        r['archived'] = true
      end
      
      #paginate for screen
      emails = emails.paginate(:per_page=>40,:page=>params[:page])

      #load hash
      emails.includes(:assigned_to).order("created_at ASC").each do |e|
        h = {'subject' => e.subject, 'created_at'=>e.created_at, 'from'=>e.from, 'id'=>e.id, 'assigned_to_id'=>e.assigned_to_id}
        r['emails'] << h
        users << e.assigned_to if e.assigned_to && !users.include?(e.assigned_to)
      end

      #include pagination details
      r['pagination'] = {}
      r['pagination']['total_pages'] = emails.total_pages
      r['pagination']['current_page'] = emails.current_page
      r['users'] = []

      #load mailbox users
      mailbox_users = m.users.to_a
      users = (users | mailbox_users)
      users.sort_by! {|u| "#{u.full_name}#{u.id}"}
      users.each do |u|
        r['users'] << {'id'=>u.id,'full_name'=>u.full_name,'allow_assign'=>mailbox_users.include?(u)}
      end
    else
      r['errors'] = ['You do not have permission to view this mailbox.']
    end
    render :json=>r.to_json
  end

  private
  def load_assignment_counts breakdown, outer_array
    breakdown.each do |user,count|
      if user.nil?
        outer_array << {'user'=>{'id'=>0,'full_name'=>'Not Assigned'},'count'=>count}
      else
        outer_array << {'user'=>{'id'=>user.id,'full_name'=>user.full_name},'count'=>count}
      end
    end
  end
end
