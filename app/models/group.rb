class Group < ActiveRecord::Base
  has_and_belongs_to_many :users, join_table: "user_group_memberships"

  has_many :workflow_tasks, inverse_of: :group

  # Finds (and creates if not found) the system group w/ the given system code
  # Uses group_name only when creating the group
  def self.use_system_group system_code, group_name = nil
    group_name = system_code if group_name.nil?
    Group.where(system_code: system_code).first_or_create! name: group_name
  end
end