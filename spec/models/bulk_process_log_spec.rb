describe BulkProcessLog do

  describe "can_view?" do
    it "should allow admins to view any log" do
      u = User.new admin:true
      expect(BulkProcessLog.new.can_view?(u)).to be_truthy
    end

    it "should allows sys admins to view any log" do
      u = User.new
      u.sys_admin = true
      expect(BulkProcessLog.new.can_view?(u)).to be_truthy
    end

    it "should allow users owning the log to view it" do
      u = User.new
      expect(BulkProcessLog.new(:user=>u).can_view?(u)).to be_truthy
    end

    it "should not allow another user to view it" do
      u = User.new
      u.id = 1

      other = User.new
      other.id = 2

      expect(BulkProcessLog.new(:user=>u).can_view?(other)).to be_falsey
    end
  end
  describe '#with_log' do
    it 'should create and yield log, calling notify_user at the end' do
      expect(BulkProcessLog.count).to eq 0
      user = Factory(:user)
      outer_log = nil
      BulkProcessLog.with_log(user, 'My Thing') do |log|
        outer_log = log # tracking outside loop to do checks on activities when loop closes
        expect(BulkProcessLog.first).to eq log
        expect(outer_log.started_at).to_not be_nil
        expect(log.user).to eq user
        expect(log.bulk_type).to eq 'My Thing'
        log.change_records.create!(recordable:Factory(:order), record_sequence_number:1)
        expect(user.messages.count).to eq 0
        expect(outer_log).to receive(:notify_user!)
      end
      outer_log.reload
      expect(outer_log.finished_at).to_not be_nil
    end
  end
  describe '#notify_user!' do
    before :each do
    end
    it 'should write user message without errors' do
      req_host = 'test.vfitrack.net'
      expect_any_instance_of(MasterSetup).to receive(:request_host).and_return req_host
      user = Factory(:user)
      bpl = BulkProcessLog.create!(user:user, changed_object_count:10, bulk_type:'My Thing')
      url = "https://#{req_host}/bulk_process_logs/#{bpl.id}"
      m = bpl.notify_user!
      expect(m.user).to eq user
      expect(m.subject).to eq "My Thing Job Complete"
      expect(m.body).to eq "<p>Your My Thing job is complete.</p><p>10 records were updated.</p><p>The full update log is available <a href=\"#{url}\">here</a>.</p>"
    end
    it 'should write user message with errrors' do
      user = Factory(:user)
      bpl = BulkProcessLog.create!(user:user, changed_object_count:10, bulk_type:'My Thing')
      bpl.change_records.create!(recordable:Factory(:order), record_sequence_number:1, failed:true)
      m = bpl.notify_user!
      expect(m.subject).to eq "My Thing Job Complete (1 error)"
    end
  end
end
