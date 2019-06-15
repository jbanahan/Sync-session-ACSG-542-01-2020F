# == Schema Information
#
# Table name: attachment_types
#
#  created_at                   :datetime         not null
#  disable_multiple_kewill_docs :boolean
#  id                           :integer          not null, primary key
#  kewill_attachment_type       :string(255)
#  kewill_document_code         :string(255)
#  name                         :string(255)
#  updated_at                   :datetime         not null
#

class AttachmentType < ActiveRecord::Base
  attr_accessible :disable_multiple_kewill_docs, :kewill_attachment_type, :kewill_document_code, :name
  scope :by_name, -> { order(name: :asc) }
end
