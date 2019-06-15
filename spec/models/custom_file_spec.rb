describe CustomFile do
  context 'security' do
    it 'should delegate view to handler' do
      handler = double "handler"
      expect(handler).to receive(:can_view?).twice.and_return(true,false)
      cf = CustomFile.new
      expect(cf).to receive(:handler).twice.and_return(handler)
      u = User.new
      expect(cf.can_view?(u)).to be_truthy
      expect(cf.can_view?(u)).to be_falsey
    end
  end
  
  context 'with functional paperclip/s3', paperclip: true, s3: true do
    let (:file_data) { Time.zone.now.to_s }
    let (:file) do
      f = Tempfile.new(["testing", ".txt"])
      f.write file_data
      f.flush
      f
    end

    after :each do
      file.close!
    end

    describe "save with attachment" do
      it 'should attach file', paperclip: true, s3: true do
        f = CustomFile.create! attached: file
        expect(OpenChain::S3.get_data('chain-io',f.attached.path)).to eq file_data
      end
    end

    describe "bucket" do
      it "returns the bucket setup for paperclip" do
        f = CustomFile.create! attached: file
        expect(f.bucket).to eq Rails.configuration.paperclip_defaults[:bucket]
      end
    end

    describe "path" do
      it "returns the path given by the paperclip object" do
        f = CustomFile.create! attached: file
        # The master setup uuid is part of the path, but it's configured in the application.rb file
        # and master setup won't exist there in test yet (in prod it's fine).  So don't test for that
        # in this test.
        expect(f.path).to end_with "custom_file/#{f.id}/#{f.attached_file_name}"
      end
    end

    describe "process" do
      let (:user) { Factory(:user) }

      class SingleArgHandler
        cattr_accessor :user
        def initialize custom_file
          @@user ||= []
        end

        def process user
          @@user << user
        end
      end

      after :each do
        SingleArgHandler.user.try(:clear)
        DoubleArgHandler.user.try(:clear)
        DoubleArgHandler.params.try(:clear)
      end

      it "processes a file, using single arg process" do
        f = CustomFile.create! attached: file, file_type: SingleArgHandler.name
        f.process user
        expect(SingleArgHandler.user).to include user
      end

      class DoubleArgHandler
        cattr_accessor :user, :params
        def initialize custom_file
          @@user ||= []
          @@params ||= []
        end

        def process user, params
          @@user << user
          @@params << params
        end
      end

      it "processes a file, using a double arg handler" do
        f = CustomFile.create! attached: file, file_type: DoubleArgHandler.name
        f.process(user, {"test" => "123"})
        expect(DoubleArgHandler.user).to include user
        expect(DoubleArgHandler.params).to include({"test" => "123"})
      end
    end
  end

  context 'status logging' do
    it "should write start and finish times" do
      h = double "handler"
      allow(h).to receive(:process).and_return('x')
      f = CustomFile.create!
      allow(f).to receive(:handler).and_return(h)
      f.process double("user")
      f.reload
      expect(f.start_at).to be > 10.seconds.ago
      expect(f.finish_at).to be > 10.seconds.ago
    end
    it "should write error" do
      h = double "handler" 
      allow(h).to receive(:process).and_raise("BAD")
      f = CustomFile.create!
      allow(f).to receive(:handler).and_return(h)
      expect {f.process double("user")}.to raise_error "BAD"
      f.reload
      expect(f.start_at).to be > 10.seconds.ago
      expect(f.finish_at).to be_nil
      expect(f.error_at).to be > 10.seconds.ago
      expect(f.error_message).to eq("BAD")
    end
    it "should clear error on good finish" do
      h = double "handler"
      allow(h).to receive(:process).and_return('x')
      f = CustomFile.create!(:error_message=>"ABC")
      allow(f).to receive(:handler).and_return(h)
      f.process double("user")
      f.reload
      expect(f.error_message).to be_nil
    end
  end
  context 'delegating to handler' do
    before :each do
      @u = Factory(:user)
    end
    it 'should get handler' do
      f = CustomFile.new(:file_type=>'Order')
      o = Order.new
      expect(Order).to receive(:new).with(f).and_return(o)
      expect(f.handler).to be o
    end
    it 'should get handler with module' do
      f = CustomFile.new(:file_type=>'OpenChain::CustomHandler::PoloCsmSyncHandler')
      expect(f.handler).to be_instance_of OpenChain::CustomHandler::PoloCsmSyncHandler 
    end
    it 'should process with handler based on file_type name' do
      handler = double "handler"
      expect(handler).to receive(:process).with(@u).and_return(['x'])
      f = CustomFile.new
      expect(f).to receive(:handler).and_return(handler)
      expect(f.process(@u)).to eq(['x'])
    end
    it 'should email updated file' do
      s3 = 's3/key'
      handler = double "handler"
      expect(handler).to receive(:make_updated_file).with(@u).and_return(s3)
      f = CustomFile.new(:attached_file_name=>'name')
      expect(f).to receive(:handler).and_return(handler)
      to = 'a@a.com'
      cc = 'b@b.com'
      subject = 'sub'
      body = 'body'
      mail = double "mail delivery"
      allow(mail).to receive(:deliver_now).and_return(nil)
      expect(OpenMailer).to receive(:send_s3_file).with(@u,to,cc,subject,body,'chain-io',s3,f.attached_file_name).and_return(mail)
      f.email_updated_file @u, to, cc, subject, body
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      c = CustomFile.new
      c.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      c.save
      expect(c.attached_file_name).to eq("___________________________________.jpg")
    end
  end

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      custom_file = nil
      Timecop.freeze(Time.zone.now - 1.second) { custom_file = CustomFile.create! }

      subject.purge Time.zone.now

      expect {custom_file.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it 'does not remove items newer than given date' do
      custom_file = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { custom_file = CustomFile.create! }

      subject.purge now

      expect { custom_file.reload }.not_to raise_error
    end
  end
end
