describe Announcement do
  let(:date) { DateTime.new 2015, 3, 15, 10 }
  let(:anc) { create(:announcement) }

  describe "validations" do
    it "validates presence of title, start_at, end_at" do
      a = described_class.create
      expect(a.errors.full_messages).to eq ["Title can't be blank", "Start at can't be blank", "End at can't be blank"]
    end

    it "validates start_at precedes end_at" do
      anc.start_at = date
      anc.end_at = date - 1.day
      anc.save
      expect(anc.errors.full_messages).to eq ["The end date must be after the start date."]
    end
  end

  describe "hide_from_user" do
    it "hides the announcement for specified user" do
      u = create(:user)
      expect(u.user_announcement_markers.count).to eq 0
      anc.hide_from_user u.id
      anc.reload
      expect(u.user_announcement_markers.first.hidden).to eq true
    end
  end
end
