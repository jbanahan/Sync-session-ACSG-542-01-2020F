# == Schema Information
#
# Table name: attachment_types
#
#  id                           :integer          not null, primary key
#  name                         :string(255)
#  created_at                   :datetime
#  updated_at                   :datetime
#  kewill_document_code         :string(255)
#  kewill_attachment_type       :string(255)
#  disable_multiple_kewill_docs :boolean
#

class AttachmentType < ActiveRecord::Base
  default_scope order("name ASC")
end
