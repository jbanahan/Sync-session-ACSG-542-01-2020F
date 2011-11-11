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
  context 'attachment handling' do
    before :each do
      @data = Time.now.to_s
      @t = Tempfile.new('a')
      @t.write @data
      @t.flush
      @f = CustomFile.create!
    end
    after :each do
      @f.delete
    end
    it 'should attach file' do
      @f.attached = @t
      @f.save!
      @f.reload
      OpenChain::S3.get_data('chain-io',@f.attached.path).should == @data
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
      f = CustomFile.new(:file_type=>'OpenChain::CustomHandler::PoloMslPlusHandler')
      f.handler.should be_instance_of OpenChain::CustomHandler::PoloMslPlusHandler 
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
end
