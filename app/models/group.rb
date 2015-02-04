class Group < ActiveRecord::Base
  has_and_belongs_to_many :users, join_table: "user_group_memberships"

  has_many :workflow_tasks, inverse_of: :group

  scope :visible_to_user, lambda {|u| 
    if u.company.master?
      Group.scoped
    else
      sql_where = <<-QRY
  SELECT g.id
  FROM groups g
  INNER JOIN user_group_memberships m ON m.group_id = g.id AND m.user_id = #{u.id}
  UNION
  SELECT g.id 
  FROM groups g
  INNER JOIN user_group_memberships m ON m.group_id = g.id
  INNER JOIN users u on u.id = m.user_id AND u.company_id = #{u.company_id}
  UNION
  SELECT g.id
  FROM groups g
  INNER JOIN user_group_memberships m ON m.group_id = g.id
  INNER JOIN users u on u.id = m.user_id
  INNER JOIN linked_companies l on u.company_id = l.child_id AND l.parent_id = #{u.company_id}
QRY
      Group.joins("INNER JOIN (#{sql_where}) subquery ON subquery.id = groups.id")
    end
  }
  # Finds (and creates if not found) the system group w/ the given system code
  # Uses group_name only when creating the group
  def self.use_system_group system_code, group_name = nil
    group_name = system_code if group_name.nil?
    Group.where(system_code: system_code).first_or_create! name: group_name
  end
end