describe ChangeRecord do
  describe "messages" do
    it 'should return all messages' do
      cr = ChangeRecord.new
      cr.add_message "x"
      cr.add_message "y"
      expect(cr.messages.to_a).to eq(["x","y"])
    end
    it 'should return empty but not nil' do
      expect(ChangeRecord.new.messages).to eq([])
    end
  end
  describe "add_message" do
    before :each do
      @cr = ChangeRecord.new
    end
    it "should build a new message" do
      msg = @cr.add_message "hello world"
      expect(msg.message).to eq("hello world")
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.size).to eq(1)
      expect(@cr.change_record_messages.first).to equal msg
    end
    it "should set failure flag" do
      msg = @cr.add_message "hello world", true
      expect(@cr).to be_failed
    end
    it "should not turn of failure flag when false is passed" do
      @cr.failed = true
      @cr.add_message "hello world", false
      expect(@cr).to be_failed
    end
  end
end
