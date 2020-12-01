describe RuntimeLog do

  let(:user) { FactoryBot(:user) }
  let(:admin_user) { FactoryBot(:admin_user) }

  describe "can_view?" do
    it "grants permission to admins" do
      log1 = FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now)

      expect(log1).not_to be_can_view(user)
      expect(log1).to be_can_view(admin_user)
    end
  end

  describe "self.find_can_view" do
    it "shows all records to sys-admins" do
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now)
      expect(described_class.find_can_view(user)).to be_nil

      expect((described_class.find_can_view admin_user).count).to eq 2
    end
  end

  describe 'purge' do
    before do
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 1.hour)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 2.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 3.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 4.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 5.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 6.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 7.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 8.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 9.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 10.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 11.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 12.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 13.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 14.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 15.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 16.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 17.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 18.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 19.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 20.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 21.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 22.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 23.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 24.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 25.hours)
      FactoryBot(:runtime_log, runtime_logable_id: 1, runtime_logable_type: 'SearchSetup', created_at: Time.zone.now - 26.hours)
    end

    it "saves 25 logs and removes the remaining" do
      expect(described_class.count).to eq 27
      described_class.purge
      expect(described_class.count).to eq 25
    end

    it "saves the given number of logs and removes the remaining" do
      expect(described_class.count).to eq 27
      described_class.purge 2
      expect(described_class.count).to eq 2
    end

    it "removes the oldest specs" do
      log1 = FactoryBot(:runtime_log, runtime_logable_id: 1,
                                   runtime_logable_type: 'SearchSetup', created_at: Time.zone.now + 1.hour)
      log2 = FactoryBot(:runtime_log, runtime_logable_id: 1,
                                   runtime_logable_type: 'SearchSetup', created_at: Time.zone.now + 2.hours)

      expect(described_class.count).to eq 29
      described_class.purge 2
      expect(described_class.count).to eq 2
      expect(described_class.first).to eq log1
      expect(described_class.last).to eq log2
    end
  end
end
