describe OpenChain::DailyStatementAttachmentZipper do
  
  let!(:user) { Factory(:user, email: "st-hubbins@hellhole.co.uk") }
  let!(:statement) { Factory(:daily_statement, statement_number: "123456") }
  
  let(:ent_1) { Factory(:entry, entry_number: "ent_num_1")}
  
  let(:file_1) { File.open("spec/fixtures/files/blank_report_1.csv") }
  let(:file_2) { File.open("spec/fixtures/files/blank_report_1.xls") }
  let(:file_3) { File.open("spec/fixtures/files/blank_report_2.csv") }
  let(:file_4) { File.open("spec/fixtures/files/blank_report_2.xls") }
  let(:file_5) { File.open("spec/fixtures/files/burlington_850_prepack.edi") }

  let!(:att_1_1) { Factory(:attachment, attachable: ent_1, attachment_type: "ENTRY PACKET", attached: file_1) }
  let!(:att_1_2) { Factory(:attachment, attachable: ent_1, attachment_type: "ENTRY SUMMARY PACK", attached: file_2) }
  let!(:att_1_3) { Factory(:attachment, attachable: ent_1, attachment_type: "7501 - ORIGINAL", attached: file_3) }
  let!(:statement_line_1) { Factory(:daily_statement_entry, daily_statement: statement, entry: ent_1) }

  let(:ent_2) { Factory(:entry, entry_number: "ent_num_2")}
  let!(:att_2_1) { Factory(:attachment, attachable: ent_2, attachment_type: "ENTRY PACKET", attached: file_4) }
  let!(:att_2_2) { Factory(:attachment, attachable: ent_2, attachment_type: "ENTRY PACKET", attached: file_5) }
  let!(:statement_line_2) {Factory(:daily_statement_entry, daily_statement: statement, entry: ent_2)}

  before { stub_paperclip; stub_master_setup }
  after { [file_1, file_2, file_3, file_4, file_5].each{ |f| f.close }  }

  def stub_get_data
    allow(OpenChain::S3).to receive(:get_data) do |bucket, key, io|
        expect(bucket).to eq "chain-io"
        
        case File.basename(key)
        when "blank_report_1.csv"
          data = "att_1_1 test data"
        when "blank_report_1.xls"
          data = "att_1_2 test data"
        when "blank_report_2.csv"
          data = "att_1_3 test data" 
        when "blank_report_2.xls"
          data = "att_2_1 test data"
        when "burlington_850_prepack.edi"
          data = "att_2_2 test data"
        end
        io << data
        io.rewind
      end
  end

  describe "zip_and_email" do
    it "sends email with specified attachments using email_opts" do
      stub_get_data  
    
      described_class.zip_and_email user.id, statement.id, ["ENTRY PACKET", "ENTRY SUMMARY PACK"], {'email' => 'tufnel@stonehenge.biz', 
                                                                                                    'subject' => 'classic album', 
                                                                                                    'body' => "Smell the Glove"}
      mail = ActionMailer::Base.deliveries.pop
      
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq 'classic album'
      expect(mail.body).to match /Smell the Glove/
      expect(mail.attachments.count).to eq 1
      att = mail.attachments["Attachments for Statement 123456.zip"]
      
      Tempfile.open('temp') do |t|
        t.binmode
        t << att.read
        t.flush
        Zip::File.open(t.path) do |zip|
          expect(zip.count).to eq 4
          expect(zip.find_entry("ent_num_1/blank_report_1.csv").get_input_stream.read).to eq "att_1_1 test data"
          expect(zip.find_entry("ent_num_1/blank_report_1.xls").get_input_stream.read).to eq "att_1_2 test data"
          expect(zip.find_entry("ent_num_2/blank_report_2.xls").get_input_stream.read).to eq "att_2_1 test data"
          expect(zip.find_entry("ent_num_2/burlington_850_prepack.edi").get_input_stream.read).to eq "att_2_2 test data"
        end
      end
    end

    it "sends email with attachments using defaults" do
      stub_get_data

      described_class.zip_and_email user.id, statement.id, ["ENTRY PACKET", "ENTRY SUMMARY PACK"], {'email' => '', 
                                                                                                    'subject' => '', 
                                                                                                    'body' => ''}
      mail = ActionMailer::Base.deliveries.pop
      
      expect(mail.to).to eq ["st-hubbins@hellhole.co.uk"]
      expect(mail.subject).to eq "Attachments for Statement 123456"
      expect(mail.body).to match /Please find attached your files for Statement 123456/
      expect(mail.attachments.count).to eq 1
      att = mail.attachments["Attachments for Statement 123456.zip"]
      expect(att).to_not be_nil
    end

    it "raises error if attachment size is over 10 MB" do
      stub_get_data

      att_1_1.update! attached_file_size: 10_485_760
      expect{ described_class.zip_and_email user.id, statement.id, ["ENTRY PACKET" ], {} }.to raise_error "Total attachment size greater than 10485760 bytes"
    end
  end

  describe "zip_and_send_message" do
    it "sends message with attachments" do
      stub_get_data

      described_class.zip_and_send_message user.id, statement.id, ["ENTRY PACKET", "ENTRY SUMMARY PACK"]

      expect(user.messages.count).to eq 1
      msg = user.messages.first
      expect(msg.subject).to eq "Attachments for Daily Statement 123456"
      expect(msg.body).to match /Click.+to download attachments./
      expect(msg.attachments.count).to eq 1
      att = msg.attachments.first
      expect(att.attached_file_name).to eq "Attachments for Statement 123456.zip"
      expect(att.uploaded_by).to eq user
      # Can't test the file contents, but should be same as for zip_and_email
    end
  end

end

