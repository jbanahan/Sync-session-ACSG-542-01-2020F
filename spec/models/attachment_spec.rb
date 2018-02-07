# encoding: utf-8
require 'spec_helper'

describe Attachment do
  describe "attachments_as_json" do
    it "should create json" do
      u = Factory(:user,first_name:'Jim',last_name:'Kirk')
      o = Factory(:order)
      a1 = o.attachments.create!(attached_file_name:'1.txt',attached_file_size:200,attachment_type:'mytype',uploaded_by_id:u.id)
      a2 = o.attachments.create!(attached_file_name:'2.txt',attached_file_size:1000000,attachment_type:'2type',uploaded_by_id:u.id)
      h = Attachment.attachments_as_json o
      expect(h[:attachable][:id]).to eq(o.id)
      expect(h[:attachable][:type]).to eq("Order")
      ha = h[:attachments]
      expect(ha.size).to eq(2)
      ha1 = ha.first
      {a1=>ha[0],a2=>ha[1]}.each do |k,v|
        expect(v[:name]).to eq(k.attached_file_name)
        expect(v[:size]).to eq(ActionController::Base.helpers.number_to_human_size(k.attached_file_size))
        expect(v[:type]).to eq(k.attachment_type)
        expect(v[:user][:id]).to eq(u.id)
        expect(v[:user][:full_name]).to eq(u.full_name)
        expect(v[:id]).to eq(k.id)
      end
    end
  end
  describe "unique_file_name" do
    it "should generate unique name" do
      a = Attachment.create(:attached_file_name=>"a.txt")
      expect(a.unique_file_name).to eq("#{a.id}-a.txt")

      a.update_attributes(:attachment_type=>"type")
      expect(a.unique_file_name).to eq("type-#{a.id}-a.txt")      
    end
    it 'should sanitize the filename' do
      a = Attachment.create(:attached_file_name=>"a.txt", :attachment_type => "Doc / Type")
      expect(a.unique_file_name).to eq("Doc _ Type-#{a.id}-a.txt")
    end
  end

  describe "can_view?" do
    it "should allow viewing for permitted users when private" do
      company = Factory(:company, master: true)
      user = Factory(:user, company: company)
      a = Attachment.new(is_private: true)
      a.attached_file_name = "test.txt"
      a.attachable = Entry.new
      a.save!
      # there's a lot of conditions to make this part true, so just mock it
      expect(a.attachable).to receive(:can_view?).with(user).and_return true
      expect(a.can_view?(user)).to be_truthy
    end

    it "should allow viewing for permitted users when not private" do
      company = Factory(:company)
      user = Factory(:user, company: company)
      a = Attachment.new(is_private: false)
      a.attached_file_name = "test.txt"
      a.attachable = Entry.new
      a.save!
      expect(a.attachable).to receive(:can_view?).with(user).and_return true
      expect(a.can_view?(user)).to be_truthy
    end

    it "should block viewing for non-permitted users" do
      company = Factory(:company, master: true)
      user = Factory(:user, company: company)
      a = Attachment.new(is_private: true)
      a.attached_file_name = "test.txt"
      a.attachable = Entry.new
      a.save!
      expect(a.attachable).to receive(:can_view?).with(user).and_return false
      expect(a.can_view?(user)).to be_falsey
    end

    context "with attachment type limitations" do
      let (:user) {Factory(:user)}
      let (:entry) {Factory(:entry, importer: user.company)}
      let (:attachment) {entry.attachments.build attached_file_name: "test.txt"}

      it "limits access to Billing Invoice attachments to only those capable of viewing BrokerInvoices" do
        a = attachment
        a.attachment_type = "BilLIng InvoICE"
        a.save!
        expect(BrokerInvoice).to receive(:can_view?).with(user, a.attachable).and_return false
        expect(a.attachable).to receive(:can_view?).with(user).and_return true
        expect(a.can_view? user).to be_falsey
      end

      it "limits access to INVOICE attachments to only those capable of viewing broker invoices" do
        a = attachment
        a.attachment_type = "Invoice"
        a.save!
        expect(BrokerInvoice).to receive(:can_view?).with(user, a.attachable).and_return false
        expect(a.attachable).to receive(:can_view?).with(user).and_return true
        expect(a.can_view? user).to be_falsey
      end

      it "limits access to Archive Packet attachments to only those capable of viewing broker invoices" do
        a = attachment
        a.attachment_type = "Archive Packet"
        a.save!
        expect(BrokerInvoice).to receive(:can_view?).with(user, a.attachable).and_return false
        expect(a.attachable).to receive(:can_view?).with(user).and_return true
        expect(a.can_view? user).to be_falsey
      end

      it "does not limit for other attachment types" do
        a = attachment
        a.attachment_type = "Random Type"
        a.save!
        expect(BrokerInvoice).not_to receive(:can_view?).with(user, a.attachable)
        expect(a.attachable).to receive(:can_view?).with(user).and_return true
        expect(a.can_view? user).to be_truthy
      end
    end
  end

  describe "add_original_filename_method" do
    it "should add original_filename accessor methods to subject object" do
      a = "test"
      Attachment.add_original_filename_method a

      expect(a.original_filename).to be_nil
      a.original_filename = "file.txt"
      expect(a.original_filename).to eq("file.txt")
    end

    it "sets a default value if given" do
      a = "test"
      Attachment.add_original_filename_method a, "filename.txt"
      expect(a.original_filename).to eq "filename.txt"
    end
  end

  describe "get_santized_filename" do
    it "should change non-latin1 chars to _" do
      f = Attachment.get_sanitized_filename "照片 014.jpg"
      expect(f).to eq("__ 014.jpg")
    end

    it "should convert invalid windows filename characters to _" do
      f = Attachment.get_sanitized_filename "\/:*?\"<>|.jpg"
      expect(f).to eq("________.jpg")
    end

    it "should convert non-printing ascii characters to _" do
      f = Attachment.get_sanitized_filename "\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      expect(f).to eq("_________________________.jpg")
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      a = Attachment.new
      a.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      a.save
      expect(a.attached_file_name).to eq("___________________________________.jpg")
    end
  end

  describe "sanitize_filename" do
    it "should sanitize filename and update the filename attribute" do
      a = Attachment.new
      a.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      Attachment.sanitize_filename a, :attached
      expect(a.attached_file_name).to eq("___________________________________.jpg")
    end

    it "should work for non-Attachment based models" do
      r = ReportResult.new
      r.report_data_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      Attachment.sanitize_filename r, :report_data
      expect(r.report_data_file_name).to eq("___________________________________.jpg")
    end

    it "removes trailing _ from extension" do
      a = Attachment.new
      a.attached_file_name = "test_file_.tif___"
      Attachment.sanitize_filename a, :attached
      expect(a.attached_file_name).to eq("test_file_.tif")
    end

    it "does not remove trailing _ if there is no extension" do
      a = Attachment.new
      a.attached_file_name = "test_file_"
      Attachment.sanitize_filename a, :attached
      expect(a.attached_file_name).to eq("test_file_")
    end
  end

  describe "email_attachments" do

    describe "large attachments" do
      before :each do
        @x = Tempfile.new("temp-a.txt")
        @y = Tempfile.new("temp-b.txt")
        @z = Tempfile.new("temp-c.txt")
        [@x,@y,@z].each {|f| f << 'hello world'; f.flush}
        OpenMailer.deliveries.clear
      end

      it "should send two emails with three attachments total if attachment sizes are about 4200000 (4.2 MB) each" do
        param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
        a = Attachment.new(attached_file_name: "a.txt")
        b = Attachment.new(attached_file_name: "b.txt")
        c = Attachment.new(attached_file_name: "c.txt")
        a.id = 1; b.id = 2; c.id = 3
        a.save!; b.save!; c.save!
        expect(Attachment).to receive(:find).with(1).and_return a
        expect(Attachment).to receive(:find).with(2).and_return b
        expect(Attachment).to receive(:find).with(3).and_return c
        expect(a).to receive(:download_to_tempfile).and_return @x
        expect(b).to receive(:download_to_tempfile).and_return @y
        expect(c).to receive(:download_to_tempfile).and_return @z
        allow(@x).to receive(:size).and_return 4200000
        allow(@y).to receive(:size).and_return 4300000
        allow(@z).to receive(:size).and_return 4400000
        #@x.should_receive(:size).exactly(6).times.and_return 4200000
        #@y.should_receive(:size).exactly(5).times.and_return 4300000
        #@z.should_receive(:size).exactly(3).times.and_return 4400000

        Attachment.email_attachments(param_hash)
        expect(OpenMailer.deliveries.length).to eq(2)
        expect(OpenMailer.deliveries.last.attachments.length + OpenMailer.deliveries[-2].attachments.length).to eq(3)
      end

      it "should send three emails with three attachments total if two attachments exceed 10MB" do
        param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
        a = Attachment.new(attached_file_name: "a.txt")
        b = Attachment.new(attached_file_name: "b.txt")
        c = Attachment.new(attached_file_name: "c.txt")
        a.id = 1; b.id = 2; c.id = 3
        a.save!; b.save!; c.save!
        expect(Attachment).to receive(:find).with(1).and_return a
        expect(Attachment).to receive(:find).with(2).and_return b
        expect(Attachment).to receive(:find).with(3).and_return c
        expect(a).to receive(:download_to_tempfile).and_return @x
        expect(b).to receive(:download_to_tempfile).and_return @y
        expect(c).to receive(:download_to_tempfile).and_return @z
        allow(@x).to receive(:size).and_return 4200000
        allow(@y).to receive(:size).and_return 11300000
        allow(@z).to receive(:size).and_return 12000000

        Attachment.email_attachments(param_hash)
        expect(OpenMailer.deliveries.length).to eq(3)
        expect(OpenMailer.deliveries.last.attachments.length).to eq(1)
        expect(OpenMailer.deliveries[-2].attachments.length).to eq(1)
        expect(OpenMailer.deliveries[-3].attachments.length).to eq(1)
      end
    end

    describe "small attachments" do 
      before :each do
        @x = Tempfile.new("temp-a.txt")
        @y = Tempfile.new("temp-b.txt")
        @z = Tempfile.new("temp-c.txt")
        [@x,@y,@z].each {|f| f << 'hello world'; f.flush}
      end

      after :each do
        [@x, @y, @z].each {|tfile| tfile.close! unless tfile.closed?}
      end

      it "should return true after success" do
        param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
        a = Attachment.new(attached_file_name: "a.txt")
        b = Attachment.new(attached_file_name: "b.txt")
        c = Attachment.new(attached_file_name: "c.txt")
        a.id = 1; b.id = 2; c.id = 3
        a.save!; b.save!; c.save!
        expect(Attachment).to receive(:find).with(1).and_return a
        expect(Attachment).to receive(:find).with(2).and_return b
        expect(Attachment).to receive(:find).with(3).and_return c
        expect(a).to receive(:download_to_tempfile).and_return @x
        expect(b).to receive(:download_to_tempfile).and_return @y
        expect(c).to receive(:download_to_tempfile).and_return @z
        expect(Attachment.email_attachments(param_hash)).to be_truthy
      end

      it "should send an email with the correct attachments" do
        param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
        a = Attachment.new(attached_file_name: "a.txt")
        b = Attachment.new(attached_file_name: "b.txt")
        c = Attachment.new(attached_file_name: "c.txt")
        a.id = 1; b.id = 2; c.id = 3
        a.save!; b.save!; c.save!
        expect(Attachment).to receive(:find).with(1).and_return a
        expect(Attachment).to receive(:find).with(2).and_return b
        expect(Attachment).to receive(:find).with(3).and_return c
        expect(a).to receive(:download_to_tempfile).and_return @x
        expect(b).to receive(:download_to_tempfile).and_return @y
        expect(c).to receive(:download_to_tempfile).and_return @z

        Attachment.email_attachments(param_hash)

        m = OpenMailer.deliveries.last
        expect(m.attachments.length).to eq(3)
        expect(m.attachments[0].filename).to eq("a.txt")
        expect(m.attachments[1].filename).to eq("b.txt")
        expect(m.attachments[2].filename).to eq("c.txt")
      end

      it "should send an email to the correct recipient" do
        param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
        a = Attachment.new(attached_file_name: "a.txt")
        b = Attachment.new(attached_file_name: "b.txt")
        c = Attachment.new(attached_file_name: "c.txt")
        a.id = 1; b.id = 2; c.id = 3
        a.save!; b.save!; c.save!
        expect(Attachment).to receive(:find).with(1).and_return a
        expect(Attachment).to receive(:find).with(2).and_return b
        expect(Attachment).to receive(:find).with(3).and_return c
        expect(a).to receive(:download_to_tempfile).and_return @x
        expect(b).to receive(:download_to_tempfile).and_return @y
        expect(c).to receive(:download_to_tempfile).and_return @z

        Attachment.email_attachments(param_hash)

        m = OpenMailer.deliveries.last
        expect(m.to.first).to eq("me@there.com")
      end

      it "should prepend attachment_type to file names when available" do
        param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
        a = Attachment.new(attached_file_name: "a.txt", attachment_type: "Type1")
        b = Attachment.new(attached_file_name: "b.txt", attachment_type: "Type2")
        c = Attachment.new(attached_file_name: "c.txt", attachment_type: "Type3")
        a.id = 1; b.id = 2; c.id = 3
        a.save!; b.save!; c.save!
        expect(Attachment).to receive(:find).with(1).and_return a
        expect(Attachment).to receive(:find).with(2).and_return b
        expect(Attachment).to receive(:find).with(3).and_return c
        expect(a).to receive(:download_to_tempfile).and_return @x
        expect(b).to receive(:download_to_tempfile).and_return @y
        expect(c).to receive(:download_to_tempfile).and_return @z

        Attachment.email_attachments(param_hash)

        m = OpenMailer.deliveries.last
        expect(m.attachments.length).to eq(3)
        expect(m.attachments[0].filename).to eq("Type1 a.txt")
        expect(m.attachments[1].filename).to eq("Type2 b.txt")
        expect(m.attachments[2].filename).to eq("Type3 c.txt")
      end
    end
  end

  describe "push_to_google_drive" do
    it "should download and attachment and push it to google drive" do
      a = Attachment.new
      a.attached_file_name = "file.txt"
      a.save

      # mock the attached call, which fails unless we actually upload a file
      attached = double("attached")
      options = {:bucket => "bucket"}
      allow_any_instance_of(Attachment).to receive(:attached).and_return attached
      expect(attached).to receive(:options).and_return options
      expect(attached).to receive(:path).and_return "s3_path"

      temp = double("Tempfile")
      path = "folder/subfolder"

      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "s3_path").and_yield temp
      expect(OpenChain::GoogleDrive).to receive(:upload_file).with("#{path}/file.txt", temp, overwrite_existing: true)

      Attachment.push_to_google_drive path, a.id
    end
  end

  describe "download_to_tempfile" do
    let (:attachment) {
      a = double("PaperclipAttachment")
      att = Attachment.new
      allow(att).to receive(:attached).and_return a
      allow(a).to receive(:path).and_return "path/to/file.txt"
      allow(a).to receive(:options).and_return bucket: "test-bucket"
      att
    }
    
    it "should use S3 to download to tempfile and yield the given block (if block given)" do
      attachment.attached_file_name = "file.txt"
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("test-bucket", "path/to/file.txt", {original_filename: "file.txt"}).and_yield "Test"

      expect(attachment.download_to_tempfile do |f|
        expect(f).to eq "Test"

        "Pass"
      end).to eq "Pass"
    end

    it "should use S3 to download to tempfile and return the tempfile (if no block given)" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('test-bucket', "path/to/file.txt", {}).and_return "Test"
      tfile = attachment.download_to_tempfile
      expect(tfile).to eq "Test"
    end
  end

  describe "stitchable_attachment?" do
    it 'identifies major image formats as stitchable' do
      ['.tif', '.tiff', '.jpg', '.jpeg', '.gif', '.png', '.bmp', '.pdf'].each do |ext|
        a = Attachment.new attached_file_name: "file#{ext}"
        expect(a.stitchable_attachment?).to be_truthy
      end
    end

    it 'identifies non-images as not stitchable' do
      a = Attachment.new attached_file_name: "file.blahblah"
      expect(a.stitchable_attachment?).to be_falsey
    end

    it "handles removed attachments names after an attachment is destroyed" do
      a = Attachment.new attached_file_name: "file.pdf"
      a.record_filename
      a.attached_file_name = nil
      expect(a.stitchable_attachment?).to be_truthy
    end

    it "disallows private attachments" do
      a = Attachment.new attached_file_name: "file.pdf", is_private: true
      expect(a.stitchable_attachment?).to be_falsey
    end
  end
end
