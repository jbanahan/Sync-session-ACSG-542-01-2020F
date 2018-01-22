# == Schema Information
#
# Table name: archived_files
#
#  id         :integer          not null, primary key
#  file_type  :string(255)
#  comment    :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_archived_files_on_created_at  (created_at)
#  index_archived_files_on_file_type   (file_type)
#

class ArchivedFile < ActiveRecord::Base
  attr_accessible :comment, :file_type
  has_one :attachment, :as => :attachable, :dependent=>:destroy

  def self.make_from_file! f, file_type, comment=nil
    af = nil
    ArchivedFile.transaction do #we don't want the archived file if the attachment blows up
      af = ArchivedFile.create!(file_type:file_type,comment:comment)
      att = af.build_attachment
      att.attached=f
      att.save!
    end
    af
  end
end
