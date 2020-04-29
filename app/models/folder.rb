# == Schema Information
#
# Table name: folders
#
#  archived         :boolean
#  base_object_id   :integer          not null
#  base_object_type :string(255)      not null
#  created_at       :datetime         not null
#  created_by_id    :integer          not null
#  id               :integer          not null, primary key
#  name             :string(255)
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_folders_on_base_object_id_and_base_object_type  (base_object_id,base_object_type)
#  index_folders_on_created_by_id                        (created_by_id)
#

class Folder < ActiveRecord::Base
  attr_accessible :archived, :base_object_id, :base_object_type, :created_by,
    :created_by_id, :name

  belongs_to :base_object, polymorphic: true, inverse_of: :folders
  belongs_to :created_by, :class_name=>"User"
  has_many :attachments, as: :attachable, dependent: :destroy, inverse_of: :attachable, autosave: true
  has_many :comments, -> { order(created_at: :desc) }, as: :commentable, dependent: :destroy, inverse_of: :commentable, autosave: true
  has_and_belongs_to_many :groups, join_table: "folder_groups"

  # Edit permissions are driven based off the groups and the owner of the folder as well as the ability of the user to access the linked core object
  def can_edit? user
    core_privilege(user) && self.base_object.respond_to?(:can_attach?) && self.base_object.can_attach?(user)
  end

  # View permissions are driven based off the groups and the owner of the folder as well as the ability of the user to access the linked core object
  def can_view? user
    core_privilege(user) && self.base_object.can_view?(user)
  end

  def can_attach? user
    can_edit? user
  end

  def can_comment? user
    can_edit? user
  end

  private
    def core_privilege user
      (user == self.created_by || self.groups.length == 0 || user.in_any_group?(self.groups))
    end
end
