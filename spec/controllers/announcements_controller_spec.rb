describe AnnouncementsController do
  let(:now) { Time.zone.now }
  let(:create_date) { now - 5.days }
  let(:start_date) { now - 2.days }
  let(:end_date) { now + 1.day }
  let(:user) { Factory :user, time_zone: "Eastern Time (US & Canada)" }
  let(:anc1) do
    a = Factory :announcement, title: "anc1", category: "all", start_at: start_date, end_at: end_date, created_at: create_date
    Factory(:user_announcement_marker, announcement: a, user: user, confirmed_at: now)
    a
  end
  let(:anc2) { Factory :announcement, title: "anc2", category: "all", start_at: now - 40.days, end_at: now - 35.days, created_at: create_date + 1.day }
  let(:anc3) do
    a = Factory :announcement, title: "anc3", category: "all", start_at: start_date, end_at: end_date, created_at: create_date + 2.days
    Factory(:user_announcement_marker, announcement: a, user: user, confirmed_at: now)
    a
  end
  let(:anc4) do
    a = Factory :announcement, title: "anc4", category: "user", start_at: start_date, end_at: end_date, created_at: create_date + 3.days
    a.selected_users << user
    Factory(:user_announcement_marker, announcement: a, user: user, confirmed_at: now)
    a
  end
  let(:anc5) do
    a = Factory :announcement, title: "anc5", category: "user", start_at: start_date, end_at: end_date, created_at: create_date + 4.days
    a.selected_users << Factory(:user)
    a
  end

  before { sign_in_as user }

  describe "index_for_user" do
    before { anc1; anc2; anc3; anc4; anc5 }

    it "renders, returning non-hidden announcements of type 'all' and 'user' announcements for current_user" do
      anc1.user_announcement_markers.first.update! hidden: true

      get :index_for_user
      expect(response).to be_ok

      assigned = assigns(:announcements)
      expect(assigned.length).to eq 2

      # anc4
      expect(assigned[0].id).to eq anc4.id
      expect(assigned[0].title).to eq anc4.title
      expect(assigned[0].start_at).to be_within(1.second).of start_date
      expect(assigned[0].confirmed_at).to be_within(1.second).of now

      # anc3
      expect(assigned[1].id).to eq anc3.id
      expect(assigned[1].title).to eq anc3.title
      expect(assigned[1].start_at).to be_within(1.second).of start_date
      expect(assigned[1].confirmed_at).to be_within(1.second).of now
    end

    it "doesn't return announcements before their adjusted_start_at" do
      Announcement.update_all start_at: now + 5.minutes # rubocop:disable Rails/SkipsModelValidations

      get :index_for_user
      expect(response).to be_ok
      expect(assigns(:announcements)).to be_empty
    end
  end

  describe "show_modal" do
    it "renders, showing new announcements" do
      expect(user).to receive(:new_announcements).and_return "announcements"

      get :show_modal, no_confirm: true
      expect(response).to be_ok
      expect(assigns(:announcements)).to eq "announcements"
      expect(assigns(:user)).to eq user
      expect(assigns(:no_confirm)).to eq true
    end

    it "renders, showing specified announcements" do
      get :show_modal, ids: "#{anc1.id},#{anc3.id}"
      expect(response).to be_ok
      expect(assigns(:announcements)).to eq [anc3, anc1]
      expect(assigns(:user)).to eq user
      expect(assigns(:no_confirm)).to be_falsy
    end
  end

end
