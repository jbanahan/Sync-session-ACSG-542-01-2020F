describe OpenChain::InactiveAccountChecker do

  describe 'run_schedulable' do
    # Let's be stupid paranoid and wrap /everything/ in Timecop. Lovely feature, this.
    Timecop.freeze(Time.zone.now) do
      before do
        @active_user = Factory(:user, last_request_at: 89.days.ago)
        @inactive_user = Factory(:user, last_request_at: 90.days.ago)
        @system_user = Factory(:user, system_user: true, last_request_at: 180.days.ago)
      end

      it 'does nothing for active users' do
        subject.run
        @active_user.reload
        expect(@active_user.password_locked).to be_falsey
        expect(@active_user.locked?).to be_falsey
      end

      it 'sets password_reset on inactive users' do
        subject.run
        @inactive_user.reload
        expect(@inactive_user.password_locked).to be_truthy
        expect(@inactive_user.locked?).to be_truthy
      end

      it 'snapshots inactive users' do
        expect_any_instance_of(User).to receive(:create_snapshot)
        subject.run
      end

      it 'does not touch system users' do
        subject.run
        @system_user.reload
        expect(@system_user.password_locked).to be_falsey
        expect(@system_user.locked?).to be_falsey

        # We want to check the query for the presence of true, as well as nil (which is default)
        @system_user.update_attribute(:system_user, true)

        @system_user.reload
        subject.run
        expect(@system_user.password_locked).to be_falsey
        expect(@system_user.locked?).to be_falsey
      end
    end
  end
end