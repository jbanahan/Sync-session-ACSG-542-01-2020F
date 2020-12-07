describe Paperclip::Validators::AttachmentExtensionBlacklistValidator do

  subject { described_class.new({attributes: {extension_blacklist: true}}) }

  describe "validate_each" do

    let (:record) { instance_double(Attachment) }
    let (:paperclip_attachment) { instance_double(Paperclip::Attachment) }

    it "rejects files that belong to extension blacklist" do
      expect(paperclip_attachment).to receive(:original_filename).and_return "FILE.EXE"
      errors = {"attached" => [] }
      expect(record).to receive(:errors).and_return(errors)

      subject.validate_each record, "attached", paperclip_attachment
      expect(errors).to eq({"attached" => ["File 'FILE.EXE' has an illegal file type of '.exe'."]})
    end

    it "allows regular file types" do
      expect(paperclip_attachment).to receive(:original_filename).and_return "file.txt"
      subject.validate_each record, "attached", paperclip_attachment
    end
  end

  describe "blacklisted?" do
    ['.bat', '.chm', '.cmd', '.com', '.cpl', '.crt', '.exe', '.hlp', '.hta', '.inf',
    '.ins', '.isp', '.jse', '.lnk', '.mdb', '.ms', '.pcd', '.pif', '.reg', '.scr', '.sct', '.shs', '.vb', '.ws'].each do |extension|

      it "blacklists '#{extension}' type files" do
        expect(subject.blacklisted? extension).to eq true
      end
    end

    it "allows other types" do
      expect(subject.blacklisted? ".txt").to eq false
    end
  end
end