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
      m.emails.includes(:assigned_to).order("created_at ASC").each do |e|
        h = {'subject' => e.subject, 'created_at'=>e.created_at, 'from'=>e.from, 'id'=>e.id, 'assigned_to_id'=>e.assigned_to_id}
        r['emails'] << h
        users << e.assigned_to if e.assigned_to && !users.include?(e.assigned_to)
      end
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
