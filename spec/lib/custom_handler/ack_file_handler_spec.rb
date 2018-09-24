require 'spec_helper'

describe OpenChain::CustomHandler::AckFileHandler do

  context "line_handling" do
    it "should take optional separator" do
      p = Factory(:product)
      t = described_class.new
      msg = "Product #{p.unique_identifier} confirmed, but it was never sent."
      expect(t).to receive(:handle_errors).with([msg],'fn', "testuser", "h|h|h\n#{p.unique_identifier}|201306191706|OK","OTHER")
      t.process_ack_file "h|h|h\n#{p.unique_identifier}|201306191706|OK", 'fn', 'OTHER', "testuser", {csv_opts:{col_sep:'|'}}
    end
    it "should handle extra whitespace" do
      p = Factory(:product)
      t = described_class.new
      msg = "Product #{p.unique_identifier} confirmed, but it was never sent."
      expect(t).to receive(:handle_errors).with([msg],'fn', "testuser", "h,h,h\n#{p.unique_identifier},201306191706,\"OK\"        ","OTHER")
      t.process_ack_file "h,h,h\n#{p.unique_identifier},201306191706,\"OK\"        ", 'fn', 'OTHER', "testuser"
    end
    
  end

  context "module_type" do
    it "should default to product handling" do
      p = Factory(:product)
      sr = p.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
      t = described_class.new
      t.process_ack_file "h,h,h\n#{p.unique_identifier},201306191706,\"OK\"", 'fn', 'OTHER', "testuser"
      sr.reload
      expect(sr.confirmed_at).not_to be_nil
    end
    it "should allow alternate module type" do
      ent = Factory(:entry,broker_reference:'123456')
      sr = ent.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
      t = described_class.new
      t.process_ack_file "h,h,h\n#{ent.broker_reference},201306191706,\"OK\"", 'fn', 'OTHER', nil, {module_type:'Entry'}
      sr.reload
      expect(sr.confirmed_at).not_to be_nil
    end
  end
  context "sync_records" do
    before :each do
      @p = Factory(:product)
      @u = Factory(:user, email: "example@example.com", username: "testuser")
    end
    it "should update product sync record" do
      @p.sync_records.create!(:trading_partner=>'XYZ')
      described_class.new.process_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'XYZ', "testuser"
      @p.reload
      expect(@p.sync_records.size).to eq(1)
      sr = @p.sync_records.first
      expect(sr.trading_partner).to eq('XYZ')
      expect(sr.confirmed_at).to be > 1.minute.ago
      expect(sr.confirmation_file_name).to eq('fn')
      expect(sr.failure_message).to be_blank
    end

    it "should not update sync record for another trading partner" do
      @p.sync_records.create!(:trading_partner=>'XYZ')
      described_class.new.process_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER', "testuser"
      @p.reload
      expect(@p.sync_records.size).to eq(1)
      sr = @p.sync_records.first
      expect(sr.trading_partner).to eq('XYZ')
      expect(sr.confirmed_at).to be_nil
    end
    it "should call errors callback if there is an error" do
      t = described_class.new
      msg = "Product #{@p.unique_identifier} confirmed, but it was never sent."
      expect(t).to receive(:handle_errors).with([msg],'fn', "testuser", "h,h,h\n#{@p.unique_identifier},201306191706,OK", "OTHER")
      t.process_ack_file "h,h,h\n#{@p.unique_identifier},201306191706,OK", 'fn', 'OTHER', "testuser"
    end
  end

  describe "parse" do
    subject { described_class }
    let (:product) { Factory(:product) }
    let! (:user) { Factory(:user, email: "example@example.com", username: "testuser") }

    it "should parse a file" do
      product.sync_records.create!(:trading_partner=>'XYZ')
      subject.parse "h,h,h\n#{product.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", :sync_code=>"XYZ", email_address: "example@example.com"}
      product.reload
      expect(product.sync_records.size).to eq(1)
      sr = product.sync_records.first
      expect(sr.confirmation_file_name).to eq('file.csv')
    end

    it "should send an email to the user provided if there's an error while processing the file" do
      user = Factory(:user, email: "me@there.com")
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: user.username})

      expect(OpenMailer.deliveries.last.to.first).to eq(user.email)
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should send an email to multiple users if there's an error while processing the file" do
      me = Factory(:user, email: "me@there.com")
      you = Factory(:user, email: "you@there.com")
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: [me.username, you.username]})

      expect((OpenMailer.deliveries.last.to - [me.email, you.email]).size).to eq(0)
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should error if key is missing" do
      expect{subject.parse "h,h,h\n#{product.unique_identifier},201306191706,OK", {:sync_code=>"XYZ", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have an s3 :key hash key."
    end

    it "should error if sync_code is missing" do
      expect{subject.parse "h,h,h\n#{product.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have a :sync_code hash key."
    end

  end
end
