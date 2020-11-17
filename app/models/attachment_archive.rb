# == Schema Information
#
# Table name: attachment_archives
#
#  company_id :integer
#  created_at :datetime         not null
#  finish_at  :datetime
#  id         :integer          not null, primary key
#  name       :string(255)
#  start_at   :datetime
#  updated_at :datetime         not null
#
# Indexes
#
#  index_attachment_archives_on_company_id  (company_id)
#

class AttachmentArchive < ActiveRecord::Base
  has_many :attachment_archives_attachments, :dependent=>:destroy
  has_many :attachments, :through=>:attachment_archives_attachments
  belongs_to :company

  # JSON of archive and its attachments
  def attachment_list_json
    self.to_json(:include=>{:attachment_archives_attachments=>{:include=>:attachment, :methods=>:output_path}})
  end

  # more_files? was removed because the client doesn't utilize the field - using it would have resulted in race conditions if multiple people are
  # archiving the same company at the same time.  The client is able to functionally duplicate the same functionality by re-polling the available docs
  # per company after finishing the current archive and seeing if any more docs are available for the same company.
end
