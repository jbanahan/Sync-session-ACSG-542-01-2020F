describe LinkableAttachmentImportRule do
  after do
    described_class.load_cache
  end

  context 'validations' do
    it 'validates unique paths' do
      create("linkable_attachment_import_rule", path: 'f')
      should_not_work = described_class.create(path: 'f', model_field_uid: 'prod_uid')
      expect(should_not_work.errors[:path].size).to eq(1)
    end

    it 'requires path' do
      should_not_work = described_class.create(model_field_uid: 'prod_uid')
      expect(should_not_work.errors[:path].size).to eq(1)
    end

    it 'requires model_field_uid' do
      should_not_work = described_class.create(path: '/something_good')
      expect(should_not_work.errors[:model_field_uid].size).to eq(1)
    end
  end

  describe 'exist_for_class?' do
    context "with_values" do
      before do
        described_class.create!(path: '/this', model_field_uid: 'ord_ord_num')
        described_class.create!(path: '/that', model_field_uid: 'prod_uid')
      end

      it "finds for module in use" do
        expect(described_class.exists_for_class?(Order)).to eq true
      end

      it "does not find for module not in use" do
        expect(described_class.exists_for_class?(Shipment)).to eq false
      end
    end
  end

  context 'import' do
    let(:file) do
      file = Tempfile.new(['linkable', 'csv'])
      file.write 'abc'
      file.flush
      file
    end

    before do
      # make some that shouldn't match
      3.times {create(:linkable_attachment_import_rule)}
    end

    after do
      file.close! if file && !file.closed?
    end

    describe 'path matching' do
      it 'returns nil if no matches' do
        result = described_class.import file, 'original_file_name.xls', '/path/not/found'
        expect(result).to be nil
      end

      it 'creates linkable attachment' do
        path = '/path/found'
        original_file_name = 'ofn.csv'
        rule = create(:linkable_attachment_import_rule, path: path)

        result = described_class.import file, original_file_name, path
        expect(result).to be_a LinkableAttachment
        expect(result).to be_persisted
        expect(result.attachment.attached_file_name).to eq original_file_name
        expect(result.model_field_uid).to eq rule.model_field_uid
      end
    end

    describe 'set linkable attachment value by original file name first segment' do
      let(:path) { '/some/path' }

      before do
        create(:linkable_attachment_import_rule, path: path)
      end

      it 'sets by space as first choice' do
        result = described_class.import file, 'a.b_some file.csv', path
        expect(result.value).to eq('a.b_some')
      end

      it 'sets by underscore as second choice' do
        result = described_class.import file, 'a.b_some.csv', path
        expect(result.value).to eq('a.b')
      end

      it 'sets by period as third choice' do
        result = described_class.import file, 'a.csv', path
        expect(result.value).to eq('a')
      end

      it 'sets full name as last choice' do
        result = described_class.import file, 'abcdef', path
        expect(result.value).to eq('abcdef')
      end

      it 'uses value override if given' do
        result = described_class.import file, 'a.b_some file.csv', path, 'x'
        expect(result.value).to eq('x')
      end
    end
  end

  describe 'find_import_rule' do
    let(:path) { '/path/found' }
    let(:orginal_file_name) { 'ofn.csv' }

    before do
      create(:linkable_attachment_import_rule, path: path)
    end

    it "returns an import rule matching the path" do
      rule = described_class.find_import_rule path
      expect(rule.id).to eq rule.id
    end

    it "does not find a rule if the path doesn't match" do
      rule = described_class.find_import_rule "a/#{path}"
      expect(rule).to be_nil
    end
  end

  describe "process_from_s3" do
    let(:file) do
      file = Tempfile.new(['linkable', 'csv'])
      file.write 'abc'
      file.flush
      file
    end

    after do
      file.close! if file && !file.closed?
    end

    it "processes a file from s3 with default paths" do
      create(:linkable_attachment_import_rule, path: '/path/to', model_field_uid: 'uid')
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', '/path/to/s3file.txt', original_filename: 's3file.txt').and_yield file

      described_class.process_from_s3 'bucket', '/path/to/s3file.txt'

      a = LinkableAttachment.first
      expect(a).not_to be_nil
      expect(a.model_field_uid).to eq "uid"
      expect(a.value).to eq "s3file"

      expect(a.attachment.attached_file_name).to eq "s3file.txt"
    end

    it "processes a file from s3 with provided paths" do
      create(:linkable_attachment_import_rule, path: '/path/to', model_field_uid: 'uid')
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', '/s3path/dir/s3file.txt', original_filename: 'file.txt').and_yield file

      described_class.process_from_s3 'bucket', '/s3path/dir/s3file.txt', original_filename: 'file.txt', original_path: "/path/to"

      a = LinkableAttachment.first
      expect(a).not_to be_nil
      expect(a.model_field_uid).to eq "uid"
      expect(a.value).to eq "file"

      expect(a.attachment.attached_file_name).to eq "file.txt"
    end

    it "logs errors" do
      r = described_class.new
      r.errors.add(:path, "Invalid Path")
      expect(described_class).to receive(:import).and_return r
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', '/s3path/dir/s3file.txt', original_filename: 'orig_file.txt').and_yield file

      described_class.process_from_s3 'bucket', '/s3path/dir/s3file.txt', original_filename: 'orig_file.txt', original_path: "/path/to"

      expect(ErrorLogEntry.last.additional_messages).to eq ["Failed to link S3 file /s3path/dir/s3file.txt using filename orig_file.txt"]
    end
  end

  describe "after_destroy" do
    it "reloads cache after destroy" do
      field = create(:linkable_attachment_import_rule, path: '/path/to', model_field_uid: 'uid')
      expect(field).to receive(:load_cache).and_call_original
      # The after cleanup above also calls load cache, hence the at_least(:once) here
      expect(described_class).to receive(:load_cache).at_least(:once).and_call_original

      field.destroy
    end
  end
end
