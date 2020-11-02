describe Api::V1::Admin::AnnouncementsController do
  let!(:user) do
    u = Factory(:admin_user, first_name: "Nigel", last_name: "Tufnel", username: "ntufnel", email: "tufnel@stonehenge.biz",
                             time_zone: "Eastern Time (US & Canada)", company: Factory(:company, name: "ACME", system_code: "AC"))
    allow_api_access u
    u
  end

  let(:user2) do
    Factory(:user, username: "dsthubbins", first_name: "David", last_name: "St. Hubbins", email: "st-hubbins@hellhole.co.uk",
                   time_zone: "Eastern Time (US & Canada)", company: Factory(:company, name: "Konvenientz", system_code: "KON"))
  end

  let(:user3) do
    Factory(:user, username: "dsmalls", first_name: "Derek", last_name: "Smalls", email: "smalls@sharksandwich.net",
                   time_zone: "Pacific Time (US & Canada)", company: Factory(:company, name: "Walshop", system_code: "WAL"))
  end

  let(:now) { Time.zone.now }

  describe "index" do

    before do
      Factory(:announcement, title: "title 1", created_at: now - 5.days)
      Factory(:announcement, title: "title 2", created_at: now - 4.days)
      Factory(:announcement, title: "title 3", created_at: now - 3.days)
      now
    end

    it "renders for admin" do
      get :index
      expect(response).to be_success
      json = JSON.parse(response.body)["announcements"]
      expect(json.count).to eq 3
      expect(json[0]["announcement"]["title"]).to eq "title 3"
      expect(json[1]["announcement"]["title"]).to eq "title 2"
      expect(json[2]["announcement"]["title"]).to eq "title 1"
    end

    it "prevents access by non-admins" do
      allow_api_access Factory(:user)
      get :index
      expect(JSON.parse(response.body)).to eq({"errors" => ["Access denied."]})
    end
  end

  describe "new" do
    before { user; user2 }

    it "renders for admin" do
      get :new

      expect(response).to be_success
      json = JSON.parse(response.body)
      excluded_users = json["announcement"]["excluded_users"]
      expect(excluded_users.count).to eq 2
      u1 = excluded_users.find { |u| u["username"] == "ntufnel" }
      u2 = excluded_users.find { |u| u["username"] == "dsthubbins" }
      expect(u2).not_to be_nil
      user_co = user.company
      expect(u1["id"]).to eq user.id
      expect(u1["first_name"]).to eq "Nigel"
      expect(u1["last_name"]).to eq "Tufnel"
      expect(u1["email"]).to eq "tufnel@stonehenge.biz"
      expect(u1["company"]).to eq({"id" => user_co.id, "name" => "ACME", "system_code" => "AC" })
    end
  end

  describe "edit" do
    let(:start_at) { DateTime.new(2020, 3, 15).in_time_zone(user.time_zone).to_s(:iso8601) }
    let(:end_at) { DateTime.new(2020, 3, 20).in_time_zone(user.time_zone).to_s(:iso8601) }
    let(:anc) do
      Factory(:announcement, title: "title", start_at: start_at, end_at: end_at, category: "users",
                             text: "message", comments: "comments")
    end

    it "renders for admin" do
      user2
      user.personal_announcements << anc
      get :edit, id: anc.id
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"announcement" =>
                                               {"id" => anc.id,
                                                "category" => "users",
                                                "start_at" => start_at,
                                                "end_at" => end_at,
                                                "text" => "message",
                                                "title" => "title",
                                                "comments" => "comments",
                                                "selected_users" =>
                                                 [{"id" => user.id,
                                                   "full_name" => "Nigel Tufnel",
                                                   "first_name" => "Nigel",
                                                   "last_name" => "Tufnel",
                                                   "email" => "tufnel@stonehenge.biz",
                                                   "email_new_messages" => false,
                                                   "username" => "ntufnel",
                                                   "company_id" => user.company.id,
                                                   "department" => nil,
                                                   "company" => {"id" => user.company.id, "name" => "ACME", "system_code" => "AC"}}],
                                                "excluded_users" =>
                                                 [{"id" => user2.id,
                                                   "full_name" => "David St. Hubbins",
                                                   "first_name" => "David",
                                                   "last_name" => "St. Hubbins",
                                                   "email" => "st-hubbins@hellhole.co.uk",
                                                   "email_new_messages" => false,
                                                   "username" => "dsthubbins",
                                                   "company_id" => user2.company.id,
                                                   "department" => nil,
                                                   "company" => {"id" => user2.company.id, "name" => "Konvenientz", "system_code" => "KON"}}]}})
    end
  end

  describe "create" do
    it "creates record for admin" do
      params =
        {announcement:
          {start_at: "2020-03-12T06:00:00.000Z",
           end_at: "2020-03-12T18:00:00.000Z",
           category: "users",
           selected_users: [user2.id],
           title: "title",
           # only adjust announcement's time, not user_announcement's
           comments: "comment",
           text: "<p>Message</p>"},
         utc_offset: -18_000}.merge(format: :json)

      expect { post :create, params }.to change(Announcement, :count).from(0).to(1)
      a = Announcement.first

      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({'announcement' => {'id' => a.id}})

      expect(a.title).to eq "title"
      expect(a.comments).to eq "comment"
      expect(a.text).to eq "<p>Message</p>"
      # The test is simulating handling a user who's browser says it's currently in central timezone, but
      # the user's account is set up to show everything in the Eastern timezone.  Ergo, the start / end
      # date is shifted an hour forward (since Eastern is one hour in front of Central)
      expect(a.start_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-12 07:00")
      expect(a.end_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-12 19:00")
      expect(a.selected_users.count).to eq 1
      expect(a.selected_users.first).to eq user2
    end

    it "ignores selected users if category set to 'all'" do
      params =
        {announcement:
          {start_at: "2020-03-12T06:00:00.000Z",
           end_at: "2020-03-12T18:00:00.000Z",
           category: "all",
           selected_users: [user2.id],
           title: "title",
           comments: "comment",
           text: "<p>Message</p>"},
         utc_offset: -18_000}.merge(format: :json)

      expect { post :create, params }.to change(Announcement, :count).from(0).to(1)
      a = Announcement.first

      expect(a.selected_users.count).to eq 0
    end

    it "returns error messages" do
      params =
        {announcement:
          {start_at: nil,
           end_at: nil,
           category: "users",
           selected_users: [user2.id],
           title: nil,
           # adjust user_announcement's time as well as announcement's
           comments: "comment",
           text: "<p>Message</p>"},
         utc_offset: -18_000}.merge(format: :json)

      post :create, params
      expect(JSON.parse(response.body)).to eq("errors" => ["Validation failed: Title can't be blank, Start at can't be blank, End at can't be blank"])
    end
  end

  describe "update" do
    let(:start_at) { ActiveSupport::TimeZone["UTC"].local(2020, 3, 15) }
    let(:end_at) { ActiveSupport::TimeZone["UTC"].local(2020, 3, 20) }
    let(:anc) do
      a = Factory(:announcement, title: "old title", start_at: start_at, end_at: end_at, category: "users",
                                 text: "<p>old message</p>", comments: "old comments")
      a.selected_users << user
      a
    end

    let(:params) do
      {id: anc.id,
       announcement:
        {start_at: "2020-03-12T06:00:00.000Z",
         end_at: "2020-03-13T18:00:00.000Z",
         category: "users",
         selected_users: [user2.id, user3.id],
         title: "new title",
         comments: "new comment",
         text: "<p>new message</p>"},
       utc_offset: -28_800}.merge(format: :json)
    end

    it "updates record for admin" do
      put :update, params

      anc.reload
      expect(anc.title).to eq "new title"
      expect(anc.comments).to eq "new comment"
      expect(anc.text).to eq "<p>new message</p>"
      expect(anc.selected_users).to eq [user2, user3]
      # The UTC offset is set for 8 hours (roughly Alaska time), however the user's actual timezone is eastern
      # timezone setting is US Eastern time.  This simulates the user traveling to a different timezone but
      # retaining their actual account's timezone
      # The math works like this...the user's browser says their offset is 8 hours (28_800 seconds)
      # but their account indicates they want time in Eastern Time (a 4 hour UTC offset).  So
      # adding 4 hours to the date time above is how this should work
      expect(anc.start_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-12 10:00")
      expect(anc.end_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-13 22:00")
    end

    it "clears selected users if category changed to 'all'" do
      params[:announcement][:category] = "all"
      put :update, params

      anc.reload
      expect(anc.selected_users).to be_empty
    end

    it "errors for missing fields" do
      params[:announcement][:start_at] = nil
      params[:announcement][:end_at] = nil
      params[:announcement][:title] = nil

      put :update, params
      expect(response).not_to be_success
      expect(JSON.parse(response.body)).to eq({"errors" => ["Title can't be blank", "Start at can't be blank", "End at can't be blank"]})
    end
  end

  describe "destroy" do
    let!(:anc) { Factory(:announcement) }

    it "destroys record for admin" do
      expect { delete :destroy, id: anc.id }.to change(Announcement, :count).from(1).to 0
    end
  end

  describe "preview_save" do
    let(:start_date) { ActiveSupport::TimeZone["UTC"].local(2020, 3, 15) }
    let(:end_date) { ActiveSupport::TimeZone["UTC"].local(2020, 3, 20) }
    let!(:anc) do
      Factory(:announcement, start_at: start_date,
                             end_at: end_date,
                             category: "all",
                             selected_users: [],
                             title: "old title",
                             comments: "old comment",
                             text: "<p>old message</p>")
    end
    let(:params) do
      {id: anc.id,
       announcement:
        { text: "<p>new message</p>"}}.merge(format: :json)
    end

    it "saves changes to the text field" do
      Timecop.freeze(start_date - 1.day) { put :preview_save, params }
      anc.reload
      expect(anc.text).to eq "<p>new message</p>"
    end
  end
end


