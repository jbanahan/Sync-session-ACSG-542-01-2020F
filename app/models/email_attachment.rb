# == Schema Information
#
# Table name: email_attachments
#
#  id            :integer          not null, primary key
#  email         :string(1024)
#  attachment_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class EmailAttachment < ActiveRecord::Base
  belongs_to :attachment
end
