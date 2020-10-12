describe CustomFile do
  let (:fake_handler) do
    Class.new do

      def can_view? user; end

      def process user; end

    end.new
  end

  context 'security' do
    it 'delegates view to handler' do
      expect(fake_handler).to receive(:can_view?).twice.and_return(true, false)
      cf = described_class.new
      expect(cf).to receive(:handler).twice.and_return(fake_handler)
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

    after do
      file.close!
    end

    describe "save with attachment" do
      it 'attaches file', paperclip: true, s3: true do
        f = described_class.create! attached: file
        expect(OpenChain::S3.get_data('chain-io', f.attached.path)).to eq file_data
      end
    end

    describe "bucket" do
      it "returns the bucket setup for paperclip" do
        f = described_class.create! attached: file
        expect(f.bucket).to eq Rails.configuration.paperclip_defaults[:bucket]
      end
    end

    describe "path" do
      it "returns the path given by the paperclip object" do
        f = described_class.create! attached: file
        # The master setup uuid is part of the path, but it's configured in the application.rb file
        # and master setup won't exist there in test yet (in prod it's fine).  So don't test for that
        # in this test.
        expect(f.path).to end_with "custom_file/#{f.id}/#{f.attached_file_name}"
      end
    end

    describe "process" do
      let (:user) { Factory(:user) }

      class SingleArgHandler # rubocop:disable RSpec/LeakyConstantDeclaration
        def process _user; end
      end

      it "processes a file, using single arg process" do
        handler = SingleArgHandler.new
        f = described_class.create! attached: file, file_type: SingleArgHandler.name
        expect(f).to receive(:handler).and_return handler
        expect(handler).to receive(:process).with(user)
        f.process user
      end

      class DoubleArgHandler # rubocop:disable RSpec/LeakyConstantDeclaration
        attr_accessor :user, :params
        def process user, params
          @user = user
          @params = params
        end
      end

      it "processes a file, using a double arg handler" do
        params = {"test" => "123"}
        f = described_class.create! attached: file, file_type: DoubleArgHandler.name
        handler = DoubleArgHandler.new
        expect(f).to receive(:handler).and_return handler
        # because we're using the method arity to determine which process method form to use
        # we can't actually mock the process method out.
        f.process(user, params)

        expect(handler.user).to eq user
        expect(handler.params).to eq params
      end
    end
  end

  context 'status logging' do
    it "writes start and finish times" do
      allow(fake_handler).to receive(:process).and_return('x')
      f = described_class.create!
      allow(f).to receive(:handler).and_return(fake_handler)
      f.process instance_double(User)
      f.reload
      expect(f.start_at).to be > 10.seconds.ago
      expect(f.finish_at).to be > 10.seconds.ago
    end

    it "delegates error handling to handle_errors method" do
      user = instance_double(User)
      error = StandardError.new "Error"

      file = described_class.create! handler: SingleArgHandler
      handler = SingleArgHandler.new
      allow(file).to receive(:handler).and_return(handler)
      expect(handler).to receive(:process).with(user).and_raise(error)

      expect(file).to receive(:handle_errors).with(handler, user, error)
      file.process user
      expect(file.start_at).not_to be_nil
      expect(file.finish_at).to be_nil
    end

    it "clears error on good finish" do
      allow(fake_handler).to receive(:process).and_return('x')
      f = described_class.create!(error_message: "ABC", error_at: Time.zone.now)
      allow(f).to receive(:handler).and_return(fake_handler)
      f.process instance_double(User)
      f.reload
      expect(f.error_message).to be_nil
      expect(f.error_at).to be_nil
    end
  end

  context 'delegating to handler' do
    let (:user) { User.new }

    it 'gets handler' do
      f = described_class.new(file_type: 'Order')
      o = Order.new
      expect(Order).to receive(:new).with(f).and_return(o)
      expect(f.handler).to be o
    end

    it 'gets handler with module' do
      f = described_class.new(file_type: 'OpenChain::CustomHandler::PoloCsmSyncHandler')
      expect(f.handler).to be_instance_of OpenChain::CustomHandler::PoloCsmSyncHandler
    end

    it 'processes with handler based on file_type name' do
      expect(fake_handler).to receive(:process).with(user).and_return(['x'])
      f = described_class.new
      expect(f).to receive(:handler).and_return(fake_handler)
      expect(f.process(user)).to eq(['x'])
    end

    it 'emails updated file' do
      s3 = 's3/key'
      def fake_handler.make_updated_file user; end

      expect(fake_handler).to receive(:make_updated_file).with(user).and_return(s3)
      f = described_class.new(attached_file_name: 'name')
      expect(f).to receive(:handler).and_return(fake_handler)
      to = 'a@a.com'
      cc = 'b@b.com'
      subject = 'sub'
      body = 'body'
      mail = instance_double(ActionMailer::MessageDelivery)
      allow(mail).to receive(:deliver_now).and_return(nil)
      expect(OpenMailer).to receive(:send_s3_file).with(user, to, cc, subject, body, 'chain-io', s3, f.attached_file_name).and_return(mail)
      f.email_updated_file user, to, cc, subject, body
    end
  end

  describe "sanitize callback" do
    it "sanitizes the attached filename" do
      c = described_class.new
      c.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      c.save
      expect(c.attached_file_name).to eq("___________________________________.jpg")
    end
  end

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      custom_file = nil
      Timecop.freeze(Time.zone.now - 1.second) { custom_file = described_class.create! }

      subject.purge Time.zone.now

      expect {custom_file.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it 'does not remove items newer than given date' do
      custom_file = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { custom_file = described_class.create! }

      subject.purge now

      expect { custom_file.reload }.not_to raise_error
    end
  end

  describe "handle_errors" do
    subject do
      c = described_class.new
      c.save!
      c
    end

    let (:error) { StandardError.new "Error" }
    let (:now) { Time.zone.now }
    let (:user) { User.new }

    it "sets the error at and error messge by default" do
      Timecop.freeze(now) do
        expect { subject.handle_errors nil, nil, error }.to raise_error error
      end
      expect(subject.error_at).to eq now
      expect(subject.error_message).to eq "Error"
    end

    it "calls through to handler's handle_uncaught_error method if implemented" do
      handler = Class.new do
        def handle_uncaught_error _user, _e
          nil
        end
      end.new

      expect(handler).to receive(:handle_uncaught_error).with(user, error)

      subject.handle_errors handler, user, error
    end
  end
end
