class Folder < ActiveRecord::Base

  belongs_to :base_object, polymorphic: true, inverse_of: :folders
  belongs_to :created_by, :class_name=>"User"
  has_many :attachments, as: :attachable, dependent: :destroy, inverse_of: :attachable, autosave: true
  has_many :comments, as: :commentable, dependent: :destroy, inverse_of: :commentable, autosave: true
  has_and_belongs_to_many :groups, join_table: "folder_groups"

  # Edit permissions are driven based off the groups and the owner of the folder as well as the ability of the user to access the linked core object
  def can_edit? user
    core_privilege(user) && self.base_object.can_edit?(user)
  end

  # View permissions are driven based off the groups and the owner of the folder as well as the ability of the user to access the linked core object
  def can_view? user
    core_privilege(user) && self.base_object.can_view?(user)
  end

  private 
    def core_privilege user
      (user == self.created_by || user.in_any_group?(self.groups))
    end
end