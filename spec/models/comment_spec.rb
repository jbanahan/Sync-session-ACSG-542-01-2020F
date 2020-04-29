describe Comment do
  describe "publish_event" do
    it "should publish event on create" do
      o = Factory(:order)
      u = Factory(:user)
      t = Time.now
      allow(Time).to receive(:now).and_return t
      expect(OpenChain::EventPublisher).to receive(:publish) do |type, obj|
        expect(type).to eq :comment_create
        expect(obj).to be_instance_of Comment
        nil
      end
      o.comments.create!(user_id:u.id, body:'abc', subject:'def')
    end
  end

  describe "gather" do
    before do
      allow_any_instance_of(Comment).to receive(:publish_comment_create)
      u = Factory(:user)
      @ord = nil
      @now = DateTime.now
      Timecop.freeze(@now - 3.hours) do
        @ord = Factory(:order)
        @ord.comments.create!(subject: "Circa 3 hours ago", body: "I said this three hours ago!", user: u)
      end
      Timecop.freeze(@now - 1.hours) { @ord.comments.create!(subject: "Circa 1 hour ago", body: "I said this one hour ago!", user: u) }
      @ord.comments.create!(subject: "Just now", body: "I said this just now", user: u)
      @timestamps = @ord.comments.order("updated_at DESC").map {|c| c.updated_at.in_time_zone(Time.zone.name).strftime('%m-%d %H:%M')}
    end

    it "collects comments for the specified obj and time frame" do
      comments = described_class.gather(@ord, @now - 2.hours)
      expect(comments).to eq "#{@timestamps[0]} Just now: I said this just now\n \n#{@timestamps[1]} Circa 1 hour ago: I said this one hour ago!"
    end

    it "limits the number of comments, if 3rd arg provided" do
      comments = described_class.gather(@ord, @now - 2.hours, 1)
      expect(comments).to eq "#{@timestamps[0]} Just now: I said this just now"
    end

    it "collects all comments if second arg nil" do
      comments = described_class.gather(@ord)
      expect(comments).to eq "#{@timestamps[0]} Just now: I said this just now\n \n#{@timestamps[1]} Circa 1 hour ago: I said this one hour ago!\n \n#{@timestamps[2]} Circa 3 hours ago: I said this three hours ago!"
    end

  end
end
