# encoding: utf-8
require 'spec_helper'

describe CustomFile do
  context 'security' do
    it 'should delegate view to handler' do
      handler = mock "handler"
      handler.should_receive(:can_view?).twice.and_return(true,false)
      cf = CustomFile.new
      cf.should_receive(:handler).twice.and_return(handler)
      u = User.new
      cf.can_view?(u).should be_true
      cf.can_view?(u).should be_false
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
  end

  context 'status logging' do
    it "should write start and finish times" do
      h = mock "handler"
      h.stub(:process).and_return('x')
      f = CustomFile.create!
      f.stub(:handler).and_return(h)
      f.process mock("user")
      f.reload
      f.start_at.should > 10.seconds.ago
      f.finish_at.should > 10.seconds.ago
    end
    it "should write error" do
      h = mock "handler" 
      h.stub(:process).and_raise("BAD")
      f = CustomFile.create!
      f.stub(:handler).and_return(h)
      lambda {f.process mock("user")}.should raise_error "BAD"
      f.reload
      f.start_at.should > 10.seconds.ago
      f.finish_at.should be_nil
      f.error_at.should > 10.seconds.ago
      f.error_message.should == "BAD"
    end
    it "should clear error on good finish" do
      h = mock "handler"
      h.stub(:process).and_return('x')
      f = CustomFile.create!(:error_message=>"ABC")
      f.stub(:handler).and_return(h)
      f.process mock("user")
      f.reload
      f.error_message.should be_nil
    end
  end
  context 'delegating to handler' do
    before :each do
      @u = Factory(:user)
    end
    it 'should get handler' do
      f = CustomFile.new(:file_type=>'Order')
      o = Order.new
      Order.should_receive(:new).with(f).and_return(o)
      f.handler.should be o
    end
    it 'should get handler with module' do
      f = CustomFile.new(:file_type=>'OpenChain::CustomHandler::PoloCsmSyncHandler')
      f.handler.should be_instance_of OpenChain::CustomHandler::PoloCsmSyncHandler 
    end
    it 'should process with handler based on file_type name' do
      handler = mock "handler"
      handler.should_receive(:process).with(@u).and_return(['x'])
      f = CustomFile.new
      f.should_receive(:handler).and_return(handler)
      f.process(@u).should == ['x']
    end
    it 'should email updated file' do
      s3 = 's3/key'
      handler = mock "handler"
      handler.should_receive(:make_updated_file).with(@u).and_return(s3)
      f = CustomFile.new(:attached_file_name=>'name')
      f.should_receive(:handler).and_return(handler)
      to = 'a@a.com'
      cc = 'b@b.com'
      subject = 'sub'
      body = 'body'
      mail = mock "mail delivery"
      mail.stub(:deliver!).and_return(nil)
      OpenMailer.should_receive(:send_s3_file).with(@u,to,cc,subject,body,'chain-io',s3,f.attached_file_name).and_return(mail)
      f.email_updated_file @u, to, cc, subject, body
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      c = CustomFile.new
      c.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      c.save
      c.attached_file_name.should == "___________________________________.jpg"
    end
  end
end
