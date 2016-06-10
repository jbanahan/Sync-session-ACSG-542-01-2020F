class Folder < ActiveRecord::Base

  belongs_to :base_object, polymorphic: true, inverse_of: :folders
  belongs_to :created_by, :class_name=>"User"
  has_many :attachments, as: :attachable, dependent: :destroy, inverse_of: :attachable, autosave: true
  has_many :comments, as: :commentable, dependent: :destroy, inverse_of: :commentable, autosave: true
  has_and_belongs_to_many :groups, join_table: "folder_groups"

end