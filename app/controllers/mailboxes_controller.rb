class MailboxesController < ApplicationController
  def index
    render :layout=>'one_col'
  end
  def show
    r = {}
    m = Mailbox.find params[:id]
    if m.can_view? current_user
      users = []
      r['id'] = m.id
      r['name'] = m.name
      r['emails'] = []
      emails = []
      if params[:assigned_to] == '0'
        emails = m.emails.where(:assigned_to_id=>nil)
        r['selected_user'] = {'id'=>0,'full_name'=>'Not Assigned'}
      elsif params[:assigned_to] 
        sel_u = User.find params[:assigned_to]
        emails = m.emails.where(:assigned_to_id=>sel_u.id)
        r['selected_user'] = {'id'=>sel_u.id,'full_name'=>sel_u.full_name}
      else
        emails = m.emails
      end
      emails = emails.paginate(:per_page=>40,:page=>params[:page])
      emails.includes(:assigned_to).order("created_at ASC").each do |e|
        h = {'subject' => e.subject, 'created_at'=>e.created_at, 'from'=>e.from, 'id'=>e.id, 'assigned_to_id'=>e.assigned_to_id}
        r['emails'] << h
        users << e.assigned_to if e.assigned_to && !users.include?(e.assigned_to)
      end
      r['pagination'] = {}
      r['pagination']['total_pages'] = emails.total_pages
      r['pagination']['current_page'] = emails.current_page
      r['users'] = []
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
end
