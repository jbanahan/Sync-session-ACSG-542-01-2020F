require 'spec_helper'

describe OpenChain::Trello do

  let (:user) {
    Factory(:user, email:'b@sample.com',first_name:'Joe',last_name:'Shmo',company:Factory(:company,name:'ACustomer'))
  }

  describe :create_feedback_card! do

    it "adds feedback card to the defined list" do
      wrapper = double("OpenChain::Trello::ApiWrapper")
      message = "hello world"
      url = "https://sample.vfitrack.net/test/something#here"

      expect(described_class).to receive(:wrapper).and_return wrapper
      body = "```\nhello world\n```\n\n**Client:** ACustomer\n**User:** Joe Shmo\n**Email:** b@sample.com\n**URL:** #{url}\n"

      expect(wrapper).to receive(:create_card_on_board!).with 'testvfiid', 'Feedback', "FB: #{user.company.name} - #{user.full_name}", body
      
      described_class.create_feedback_card! user.id, url, message
    end
  end

  describe "send_support_request!" do
    let (:request) {
      r = SupportRequest.new user: user, created_at: Time.zone.parse("2015-12-29 15:00"), referrer_url: "http://www.vfitrack.net", body: "Help!"
      allow(r).to receive(:id).and_return 1
      r
    }

    it "generates card data and creates it" do
      card_name = "Ticket # 1 - #{user.email}"
      card_body = "```\nHelp!\n```\n\n**Submitted:** 2015-12-29 10:00 AM EST\n**Client:** ACustomer\n**User:** Joe Shmo\n**Email:** b@sample.com\n**URL:** http://www.vfitrack.net\n\n"

      expect(described_class).to receive(:create_card_on_board!).with("board-id", "list-name", card_name, card_body, label_colors: "label-color")

      described_class.send_support_request! "board-id", "list-name", request, "label-color"
    end
  end

  describe "create_support_request!" do
    let (:wrapper) { double("OpenChain::Trello::ApiWrapper") }

    it "passes through values to api wrapper" do
      expect(wrapper).to receive(:create_card_on_board!).with "board-id", "list_name", "card name", "card body", {opts: "opt"}

      expect(described_class).to receive(:wrapper).and_return wrapper

      described_class.create_card_on_board! "board-id", "list_name", "card name", "card body", {opts: "opt"}
    end
  end

  describe OpenChain::Trello::ApiWrapper do
    subject { OpenChain::Trello::ApiWrapper.new }

    describe 'configuration' do
      it "should load trello configuration on class load" do
        subject
        config = ::Trello.configuration
        # /config/trello.yml
        expect(config.developer_public_key).to eq 'testkey'
        expect(config.member_token).to eq 'testtoken'
      end
    end

    describe "create_card_on_board!" do

      let (:list) {
        list = double("Trello::List")
        allow(list).to receive(:id).and_return "list-id"
        list
      }

      let (:labels) {
        red = double("Trello::Label")
        allow(red).to receive(:color).and_return "red"
        allow(red).to receive(:id).and_return "label-red"

        blue = double("Trello::Label")
        allow(blue).to receive(:color).and_return "blue"
        allow(blue).to receive(:id).and_return "label-blue"
        [red, blue]
      }

      let (:board) {
        board = double("Trello::Board")
        allow(board).to receive(:id).and_return "board-id"
        allow(board).to receive(:labels).and_return labels
        board
      }

      
      it "uses Trello::Card.create to create a card" do
        expect(subject).to receive(:with_list).with(board.id, "List Name").and_yield list

        expect(Trello::Card).to receive(:create).with({list_id: list.id, name: "Card Name", desc: "Card Body", option1: "opt", option2: "opt2"})

        subject.create_card_on_board! board.id, "List Name", "Card Name", "Card Body", option1: "opt", option2: "opt2"
      end

      it "accepts option for label_color and applies it" do
        expect(subject).to receive(:with_list).with(board.id, "List Name").and_yield list
        expect(subject).to receive(:with_board).with(board.id).and_yield board


        expect(Trello::Card).to receive(:create).with({list_id: list.id, name: "Card Name", desc: "Card Body", option1: "opt", option2: "opt2", card_labels: "label-red"})
        subject.create_card_on_board! board.id, "List Name", "Card Name", "Card Body", option1: "opt", option2: "opt2", label_colors: "red"
      end

      it "accepts multiple label colors" do
        expect(subject).to receive(:with_list).with(board.id, "List Name").and_yield list
        expect(subject).to receive(:with_board).with(board.id).and_yield board


        expect(Trello::Card).to receive(:create).with({list_id: list.id, name: "Card Name", desc: "Card Body", option1: "opt", option2: "opt2", card_labels: "label-red,label-blue"})
        subject.create_card_on_board! board.id, "List Name", "Card Name", "Card Body", option1: "opt", option2: "opt2", label_colors: "red, blue"
      end
    end

    describe "with_board" do
      let (:board) {
        board = double("Trello::Board")
        allow(board).to receive(:id).and_return "board-id"
        board
      }

      it "looks up a board and yields it to the caller, returning the result of the block" do
        expect(Trello::Board).to receive(:find).with(board.id).and_return board
        expect(subject.with_board(board.id) {|b| b.id}).to eq board.id
      end

      context "with cached board lookup" do
        let (:board_2) {
          board = double("Trello::Board")
          allow(board).to receive(:id).and_return "board2-id"
          board
        }

        before :each do
          allow(Trello::Board).to receive(:find).with(board.id).once.and_return board
          subject.with_board(board.id) {|b| b.id}
        end
        
        it "caches the result of the board lookup" do
          expect(subject.with_board(board.id) {|b| b.id}).to eq board.id
        end

        it "explodes cache if different board id is given" do
          allow(Trello::Board).to receive(:find).with(board_2.id).once.and_return board_2
          expect(subject.with_board(board_2.id) {|b| b.id}).to eq board_2.id
          # Call again to make sure the second call is cached
          expect(subject.with_board(board_2.id) {|b| b.id}).to eq board_2.id
        end
      end
    end

    describe "with_list" do
      let (:board) {
        board = double("Trello::Board")
        allow(board).to receive(:id).and_return "board-id"
        allow(board).to receive(:name).and_return "Board Name"
        board
      }

      let (:list) {
        list = double("Trello::List")
        allow(list).to receive(:id).and_return "list-id"
        allow(list).to receive(:name).and_return "list-name"
        list
      }

      before :each do
        allow(subject).to receive(:with_board).with(board.id).and_yield board
      end

      it "finds and yields the requested list" do
        expect(board).to receive(:lists).and_return [list]
        expect(subject.with_list(board.id, list.name) {|l| l.id}).to eq list.id
      end

      it "creates the requested list if missing" do
        expect(board).to receive(:lists).and_return []
        expect_any_instance_of(OpenChain::Trello::ApiWrapper).to receive(:create_list!).with(board.id, list.name).and_return list

        expect(subject.with_list(board.id, list.name) {|l| l.id}).to eq list.id
      end

      it "raises an error if instructed when the list is missing" do
        expect(board).to receive(:lists).and_return []
        expect { subject.with_list(board.id, list.name, true) {|l| l.id} }.to raise_error "Unable to find a list named #{list.name} on the board #{board.name}"
      end
    end

    describe "find_label_ids_by_colors" do

      let (:labels) {
        red = double("Trello::Label")
        allow(red).to receive(:color).and_return "red"
        allow(red).to receive(:id).and_return "label-red"

        blue = double("Trello::Label")
        allow(blue).to receive(:color).and_return "blue"
        allow(blue).to receive(:id).and_return "label-blue"
        [red, blue]

        magenta = double("Trello::Label")
        allow(magenta).to receive(:color).and_return "magenta"
        allow(magenta).to receive(:id).and_return "label-magenta"
        [red, blue, magenta]
      }

      let (:board) {
        board = double("Trello::Board")
        allow(board).to receive(:id).and_return "board-id"
        allow(board).to receive(:labels).and_return labels
        board
      }

      before :each do
        allow(subject).to receive(:with_board).with(board.id).and_yield board
      end

      it "finds label ids for a specific set of colors" do
        label_ids = subject.find_label_ids_by_colors board.id, "red, blue"
        expect(label_ids).to eq ["label-red", "label-blue"]
      end

      it "rejects colors that are not actual Trello label colors" do
        expect(subject.find_label_ids_by_colors board.id, "magenta").to eq []
      end

      it "doesn't look up the board, and returns blank array if colors is blank" do
        expect(subject).not_to receive(:with_board)
        expect(subject.find_label_ids_by_colors nil, nil).to eq []
      end
    end
  end
end