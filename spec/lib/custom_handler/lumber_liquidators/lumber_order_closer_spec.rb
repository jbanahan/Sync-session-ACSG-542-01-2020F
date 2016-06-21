require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderCloser do
  describe '#process' do
    it "should convert flat file data and user id call go" do
      OpenChain::S3.should_receive(:bucket_name).and_return('mybucket')
      OpenChain::S3.should_receive(:get_data).with('mybucket','mypath').and_return("ABC\nDEF\n")
      u = double(:user)
      effective_date = double(:date)
      User.should_receive(:find).with(99).and_return u

      described_class.should_receive(:go).with(["ABC","DEF"], effective_date, u)
      OpenChain::S3.should_receive(:delete).with('mybucket', 'mypath')

      described_class.process('mypath', effective_date, 99)
    end
  end
  describe '#go' do
    it 'should call open_closed_orders and close_orders' do
      nums = double('order_numbers')
      u = double('user')
      effective_date = double(:date)
      described_class.should_receive(:open_closed_orders).with(nums,u).and_return 10
      described_class.should_receive(:close_orders).with(nums, effective_date, u).and_return 1
      described_class.should_receive(:send_completion_message).with(10,1,u)

      described_class.go nums, effective_date, u
    end
  end
  describe '#open_closed_orders' do
    it 'should open closed orders' do
      o = Factory(:order,order_number:'12345',closed_at:Time.now)
      keep_closed = Factory(:order,closed_at:Time.now)
      described_class.open_closed_orders ['12345'], Factory(:user)

      o.reload
      expect(o.closed_at).to be_nil

      keep_closed.reload
      expect(keep_closed.closed_at).to_not be_nil
    end
  end
  describe '#close_orders' do
    before :each do
      @effective_date = Date.today - 1
      @keep_open = Factory(:order,order_number:'12345', order_date: @effective_date)
      @close = Factory(:order, order_date: @effective_date - 1)
    end
    
    it 'should close open orders not on list' do
      described_class.close_orders ['12345'], @effective_date, Factory(:user)

      @keep_open.reload
      expect(@keep_open.closed_at).to be_nil

      @close.reload
      expect(@close.closed_at).to_not be_nil
    end

    it 'skips unlisted orders on/after effective_date' do
      @close.update_attributes(order_date: @effective_date)
      described_class.close_orders ['12345'], @effective_date, Factory(:user)

      @keep_open.reload
      expect(@keep_open.closed_at).to be_nil

      @close.reload
      expect(@close.closed_at).to be_nil
    end
  end
end
