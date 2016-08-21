require 'spec_helper'

describe ArchivedFile do
  describe :make_from_file! do
    it "should make with file" do
      f = double('file')
      t = 'filetype'
      c = 'comm'
      expect_any_instance_of(Attachment).to receive(:attached=).with(f)
      af = ArchivedFile.make_from_file! f, t, c
      af = ArchivedFile.find af.id #reload from scratch
      expect(af.attachment).not_to be_nil
      expect(af.file_type).to eq(t)
      expect(af.comment).to eq(c)
    end
    
  end
end
