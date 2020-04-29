# == Schema Information
#
# Table name: email_attachments
#
#  attachment_id :integer
#  created_at    :datetime         not null
#  email         :string(1024)
#  id            :integer          not null, primary key
#  updated_at    :datetime         not null
#

class EmailAttachment < ActiveRecord::Base
  attr_accessible :attachment_id, :email

  belongs_to :attachment
end
