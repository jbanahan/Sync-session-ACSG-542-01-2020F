class PowerOfAttorney < ActiveRecord::Base
  belongs_to :company
  belongs_to :user, :foreign_key => :uploaded_by, :class_name => "User"

  has_attached_file :attachment,
    :storage => :fog,
    :fog_credentials => FOG_S3,
    :fog_public => false,
    :fog_directory => 'chain-io',
    :path => "#{MasterSetup.get.nil? ? "UNKNOWN" : MasterSetup.get.uuid}/power_of_attorney/:id/:filename" #conditional on MasterSetup to allow migrations to run

  validates_attachment_presence :attachment
end
