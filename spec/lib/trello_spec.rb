require 'spec_helper'

describe OpenChain::Trello do

  describe :create_feedback_card! do
    before :each do
      @u = Factory(:user, email:'b@sample.com',first_name:'Joe',last_name:'Shmo',company:Factory(:company,name:'ACustomer'))
      @message = 'hello world'
      @url = "https://sample.vfitrack.net/test/something#here"
      @board_id = 'testvfiid' # /config/trello.yml
      @list_name = 'Feedback'

      @expected_name = "FB: ACustomer - Joe Shmo"
      @expected_message = "```\nhello world\n```\n\n**Client:** ACustomer\n**User:** Joe Shmo\n**Email:** b@sample.com\n**URL:** #{@url}\n"

      @api = described_class::ApiWrapper
    end

    it "should add to list" do
      list = double('list')
      list.stub(:id).and_return('l-id')
      @api.should_receive(:find_or_create_list_by_name!).with(@board_id,'Feedback').and_return(list)
      @api.should_receive(:create_card!).with('l-id',@expected_name,{desc:@expected_message})

      described_class.create_feedback_card! @u.id, @url, @message
    end

  end

  describe OpenChain::Trello::ApiWrapper do
    describe 'configuration' do
      it "should load trello configuration on class load" do
        described_class
        config = ::Trello.configuration
        # /config/trello.yml
        expect(config.developer_public_key).to eq 'testkey'
        expect(config.member_token).to eq 'testtoken'
      end
    end

    describe :find_list_by_name do
      before :each do
        @board = double('board')
        ::Trello::Board.should_receive(:find).with('BN').and_return(@board)
        @lists = ["ABC","DEF","GHI"].collect do |n|
          l = double("list-#{n}")
          l.stub(:name).and_return n
          l.stub(:id).and_return "#{n}-ID"
          l
        end
        @board.stub(:lists).and_return(@lists)
      end

      it "should find list by looping board" do
        expect(described_class::ApiWrapper.find_list_by_name('BN','DEF').id).to eq 'DEF-ID'
      end

      it "should return nil if not found" do
        expect(described_class::ApiWrapper.find_list_by_name('BN','Z')).to be_nil
      end
    end

    describe :find_or_create_list_by_name! do
      it "should find" do
        create_opts = {pos:1}
        list = double('list')
        described_class::ApiWrapper.should_receive(:find_list_by_name).with('BN','Z').and_return list
        expect(described_class::ApiWrapper.find_or_create_list_by_name!('BN','Z',create_opts)).to eq list
      end
      it "should create" do
        create_opts = {pos:1}
        list = double('list')
        described_class::ApiWrapper.should_receive(:find_list_by_name).with('BN','Z').and_return nil
        described_class::ApiWrapper.should_receive(:create_list!).with('BN','Z',create_opts).and_return list
        expect(described_class::ApiWrapper.find_or_create_list_by_name!('BN','Z',create_opts)).to eq list
      end
    end

    describe :create_list! do
      it "should create list" do
        expected_opts = {name:'n',board_id:'BN',pos:55}
        list = double('list')
        ::Trello::List.should_receive(:create).with(expected_opts).and_return(list)
        
        expect(described_class::ApiWrapper.create_list!('BN','n', {pos:55})).to eq list        
      end
    end

    describe :create_card! do
      it "should create card" do
        expected_opts = {name:'n',list_id:'abc',desc:'des'}
        mock_card = double('card')
        ::Trello::Card.should_receive(:create).with(expected_opts).and_return(mock_card)
        
        expect(described_class::ApiWrapper.create_card! 'abc', 'n', {desc: 'des'}).to eq mock_card
      end
    end
  end
end