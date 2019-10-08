describe OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler do

  let! (:inbound_file) {
    f = InboundFile.new
    f.file_name = "file.csv"
    allow_any_instance_of(described_class).to receive(:inbound_file).and_return f
    f
  }

  describe "process_ack_file" do
    it "should not report error for missing style if it's a related style" do
      cdefs = described_class.prep_custom_definitions [:related_styles]
      p = Factory(:product) 
      p.sync_records.create!(trading_partner:'XYZ')
      p.update_custom_value! cdefs[:related_styles], 'REL123'
      subject.process_ack_file "h,h,h\nREL123,2013060191051,OK", 'XYZ', "chainio_admin", {email_warnings: true}
      p.reload
      sr = p.sync_records.first
      expect(sr.confirmed_at).to be > 1.minute.ago
      expect(sr.confirmation_file_name).to eq('file.csv')
      expect(sr.failure_message).to be_blank
    end
  end

  describe "get_ack_file_errors" do
    it "should report real missing style" do
      errors = subject.get_ack_file_errors "h,h,h\nREL123,2013060191051,OK", 'file.csv', 'XYZ', {email_warnings: true}
      expect(errors.size).to eq(1)
      expect(errors.first).to eq("Product REL123 confirmed, but it does not exist.")
    end
  end
end
