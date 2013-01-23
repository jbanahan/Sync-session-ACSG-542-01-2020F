class AttachmentArchive < ActiveRecord::Base
  attr_accessible :company_id, :finish_at, :name, :start_at

  has_many :attachment_archives_attachments, :dependent=>:destroy
  has_many :attachments, :through=>:attachment_archives_attachments
  belongs_to :company

  #JSON of archive and its attachments
  def attachment_list_json 
    self.to_json(:methods=>[:more_files?],:include=>{:attachment_archives_attachments=>{:include=>:attachment}})
  end

  #are there more files currently available for the given company_id
  def more_files?
    self.company.attachment_archive_setup.entry_attachments_available?
  end
end
