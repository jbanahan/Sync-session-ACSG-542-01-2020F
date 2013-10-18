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
