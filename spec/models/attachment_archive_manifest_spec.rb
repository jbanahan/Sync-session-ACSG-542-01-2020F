describe AttachmentArchiveManifest do
  before :each do
    @c = Factory(:company)
  end
  describe "make_manifest!" do
    it "should create attachment and update time" do
      @man = @c.attachment_archive_manifests.create!(:start_at=>1.hour.ago)
      @base_time = 2.days.ago
      @tmp = double("tmp")
      expect(@tmp).to receive(:unlink)
      @att = double("attachment")
      expect(@att).to receive(:attached=).with(@tmp)
      expect(@att).to receive(:save!)
      allow(@man).to receive(:attachment).and_return(nil)
      allow(@man).to receive(:create_attachment).and_return(@att)
      expect(@man).to receive(:generate_manifest_tempfile!).with(@base_time).and_return(@tmp)
      @man.make_manifest! @base_time
      @man.reload
      expect(@man.finish_at).to be > 1.minute.ago
    end
  end

  describe "generate_manifest_tempfile!" do
    before :each do
      @rel_date = 1.day.ago
      @ent = Factory(:entry, :importer=>@c, :broker_reference=>'123', :entry_number=> 'abc123', :release_date=>@rel_date, :master_bills_of_lading=>'mbol', :arrival_date=>1.day.ago, :po_numbers => "PO")
      @inv = Factory(:broker_invoice, :entry=>@ent, :invoice_date => 2.months.ago)
      @att1 = @ent.attachments.create!(:attached_file_name=>'a.txt', :attached_file_size=>100, :attachment_type=>'EDOC')
      @a_setup = @c.create_attachment_archive_setup(:start_date=>10.years.ago)
      # Make sure to create the archives and attachments separately to ensure the attachments are attached to the archvies
      # in a repeatable order
      @archive1 = @a_setup.create_entry_archive! "aname", 101
      @att2 = @ent.attachments.create!(:attached_file_name=>'b.txt', :attached_file_size=>100, :attachment_type=>'7501')
      @archive2 = @a_setup.create_entry_archive! "bname", 101
      @m = @c.attachment_archive_manifests.create!(:start_at=>Time.now)
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it "should create excel temp file" do
      @tmp = @m.generate_manifest_tempfile! 1.year.ago
      # Make sure the tempfile is rewound before reading.
      expect(@tmp.read).not_to eq ""
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      title_row = sheet.row(0)
      ["Archive Name", "Archive Date", "Entry Number", "Broker Reference", "Master Bill of Lading", "PO Numbers",
        "Release Date", "Doc Type", "Doc Name"].each_with_index do |n, i|
        expect(title_row[i]).to eq(n)
      end

      # There's no real order involved in making the spreadsheet, so just make our own here so they appear in the order we expect
      lines = [sheet.row(1), sheet.row(2)].sort {|a, b| a[0] <=> b[0]}
      r = lines[0]

      expect(r[0]).to eq("aname")
      expect(r[1]).to eq(Time.now.to_date)
      expect(r[2]).to eq('abc123')
      expect(r[3]).to eq('123')
      expect(r[4]).to eq('mbol')
      expect(r[5]).to eq("PO")
      expect(r[6]).to eq(@rel_date.to_date)
      expect(r[7]).to eq('EDOC')
      expect(r[8]).to eq(@att1.unique_file_name)

      r = lines[1]
      expect(r[0]).to eq("bname")
      expect(r[1]).to eq(Time.now.to_date)
      expect(r[2]).to eq('abc123')
      expect(r[3]).to eq('123')
      expect(r[4]).to eq('mbol')
      expect(r[5]).to eq("PO")
      expect(r[6]).to eq(@rel_date.to_date)
      expect(r[7]).to eq('7501')
      expect(r[8]).to eq(@att2.unique_file_name)

      r = sheet.row(3)
      expect(r[0]).to be_nil
    end
    it "should ignore old archives" do
      @archive1.update_attributes(:start_at=>5.years.ago)
      @tmp = @m.generate_manifest_tempfile! 1.year.ago
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      expect(sheet.row(1)[0]).to eq(@archive2.name)
      expect(sheet.row(2)[0]).to be_nil
    end
  end
end
