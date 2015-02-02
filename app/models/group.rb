class Group < ActiveRecord::Base
  has_and_belongs_to_many :users, join_table: "user_group_memberships"

  has_many :workflow_tasks, inverse_of: :group

  scope :visible_to_user, lambda {|u| 
    if u.company.master?
      Group.scoped
    else
      sql_where = <<-QRY
(user_group_memberships.user_id = #{u.id}) 
OR 
(user_group_memberships.user_id IN (select user_id from users where company_id = #{u.company_id}))
OR
(user_group_memberships.user_id IN (select user_id from users where company_id IN (select child_id from linked_companies where parent_id = #{u.company_id})))
QRY
      Group.joins('INNER JOIN user_group_memberships ON user_group_memberships.group_id = groups.id').where(sql_where)
    end
  }
  # Finds (and creates if not found) the system group w/ the given system code
  # Uses group_name only when creating the group
  def self.use_system_group system_code, group_name = nil
    group_name = system_code if group_name.nil?
    Group.where(system_code: system_code).first_or_create! name: group_name
  end
end