require 'spec_helper'

describe ArchivedFile do
  describe :make_from_file! do
    it "should make with file" do
      f = double('file')
      t = 'filetype'
      c = 'comm'
      Attachment.any_instance.should_receive(:attached=).with(f)
      af = ArchivedFile.make_from_file! f, t, c
      af = ArchivedFile.find af.id #reload from scratch
      af.attachment.should_not be_nil
      af.file_type.should == t
      af.comment.should == c
    end
    
  end
end
