# == Schema Information
#
# Table name: groups
#
#  created_at  :datetime         not null
#  description :string(255)
#  id          :integer          not null, primary key
#  name        :string(255)
#  system_code :string(255)
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_groups_on_system_code  (system_code) UNIQUE
#

class Group < ActiveRecord::Base
  attr_accessible :description, :name, :system_code
  
  has_and_belongs_to_many :users, join_table: "user_group_memberships"

  validates :name, presence: true
  validates :system_code, presence: true
  validates :system_code, uniqueness: true, unless: Proc.new {|g| g.system_code.blank? }

  scope :visible_to_user, lambda {|u|
    if u.company.master?
      Group.all
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
  # Uses group name and description only when creating the group.
  def self.use_system_group system_code, name: nil, create: true, description: nil
    g = Group.where(system_code: system_code)
    if create
      group_name = name.nil? ? system_code : name
      g.first_or_create! name: (group_name.blank? ? system_code : group_name), description: description
    else
      g.where(system_code: system_code).first
    end
  end

  def user_emails
    users.where("length(trim(email)) > 0").pluck :email
  end
end
