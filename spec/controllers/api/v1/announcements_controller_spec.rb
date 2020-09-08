describe Api::V1::AnnouncementsController do
  let!(:user) do
    u = Factory(:user, email: "tufnel@stonehenge.biz")
    allow_api_access u
    u
  end

  describe "confirm" do
    let!(:anc1) { Factory(:announcement) }
    let!(:anc2) { Factory(:announcement, title: "hear, ye!", text: "This is important!") }
    let!(:anc3) { Factory(:announcement) }

    it "marks specified user_announcement_markers 'confirmed' for current user, sends email if indicated" do
      now = Time.zone.local(2020, 3, 15)

      message_delivery = instance_double(ActionMailer::MessageDelivery)
      expect(OpenMailer).to receive(:send_announcement).with(anc2.id, user.id).and_return message_delivery
      expect(message_delivery).to receive(:deliver_later)

      Timecop.freeze(now) { put :confirm, anc_ids: [anc1.id, anc2.id], email_anc_ids: [anc2.id] }
      expect(user.user_announcement_markers[0].confirmed_at).to eq now
      expect(user.user_announcement_markers[1].confirmed_at).to eq now
      anc3.reload
      expect(anc3.user_announcement_markers.count).to eq 0
    end

    it "correctly handles request without email ids" do
      now = Time.zone.local(2020, 3, 15)
      expect(OpenMailer).not_to receive(:send_announcement)

      Timecop.freeze(now) { put :confirm, anc_ids: [anc1.id, anc2.id], email_anc_ids: nil }
      expect(user.user_announcement_markers[0].confirmed_at).to eq now
      expect(user.user_announcement_markers[1].confirmed_at).to eq now
      anc3.reload
      expect(anc3.user_announcement_markers.count).to eq 0
    end

    it "ignores user_announcement_markers with a populated confirmed_at field" do
      now = Time.zone.local(2020, 3, 15)
      yesterday = now - 1.day
      uam = Factory(:user_announcement_marker, announcement: anc1, user: user, confirmed_at: yesterday)
      Timecop.freeze(now) { put :confirm, anc_ids: anc1.id.to_s }
      uam.reload
      expect(uam.confirmed_at).to eq yesterday
    end
  end

  describe "count" do
    it "returns the quantity of new user_announcements for current user" do
      anc1 = instance_double(Announcement)
      anc2 = instance_double(Announcement)
      expect_any_instance_of(User).to receive(:new_announcements) do |u|
        expect(u.id).to eq user.id
        [anc1, anc2]
      end

      get :count

      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({'count' => 2})
    end
  end

  describe "hide_from_user" do
    it "sets 'hidden' flag on user_announcement for specified announcement" do
      anc = Factory(:announcement)
      user.marked_announcements << anc
      expect(user.user_announcement_markers.first.hidden).to be_falsy

      put :hide_from_user, id: anc.id

      expect(user.user_announcement_markers.first.hidden).to eq true
    end
  end

end
