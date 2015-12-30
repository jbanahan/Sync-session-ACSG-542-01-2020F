require 'yaml'
require 'trello'
module OpenChain; class Trello

  setup = YAML.load_file('config/trello.yml')[Rails.env]
  VFI_TRACK_PRIORITY_BOARD_ID ||= setup['vfi_track_priority_board_id']
  DEV_PUB_KEY ||= setup['developer_public_key']
  MEMBER_TOKEN ||= setup['member_token']

  def self.create_feedback_card! user_id, url, message
    u = User.find(user_id)
    card_name = "FB: #{u.company.name} - #{u.full_name}"
    card_description = <<DESC
```
#{message}
```

**Client:** #{u.company.name}
**User:** #{u.full_name}
**Email:** #{u.email}
**URL:** #{url}
DESC

    wrapper.create_card_on_board! VFI_TRACK_PRIORITY_BOARD_ID, 'Feedback', card_name, card_description
    nil
  end

  def self.send_support_request! board_id, list_name, support_request, label_color
    card_name = "Ticket # #{support_request.id} - #{support_request.user.email}"
    card_body = <<DESC
```
#{support_request.body}
```

**Submitted:** #{support_request.created_at.in_time_zone("America/New_York").strftime("%Y-%m-%d %I:%M %p %Z")}
**Client:** #{support_request.user.company.name}
**User:** #{support_request.user.full_name}
**Email:** #{support_request.user.email}
**URL:** #{support_request.referrer_url}

DESC
    create_card_on_board! board_id, list_name, card_name, card_body, label_colors: label_color
  end

  # You can assume if this method returns, the card has been created
  def self.create_card_on_board! board_id, list_name, card_name, card_body, card_opts = {}
    wrapper.create_card_on_board! board_id, list_name, card_name, card_body, card_opts
  end


  def self.wrapper
    ApiWrapper.new
  end
  #############
  #
  # Methods that work with the API directly are below
  # 
  # these generally should not be used outside of this class as 
  # it mostly leaks the abstraction from the underlying gem
  #
  #############
  class ApiWrapper

    def initialize
      init
    end

    def init
      unless defined?(@@initialized)
        ::Trello.configure do |config|
          config.developer_public_key = OpenChain::Trello::DEV_PUB_KEY
          config.member_token = OpenChain::Trello::MEMBER_TOKEN
        end

        @@initialized = true
      end
    end

    def create_card_on_board! board_id, list_name, card_name, card_body, opts = {}
      with_list(board_id, list_name) do |list|
        
        card_opts = {list_id: list.id, name: card_name, desc: card_body}.merge opts
        labels = find_label_ids_by_colors board_id, card_opts.delete(:label_colors)
        if !labels.blank?
          card_opts[:card_labels] = labels.join(",")
        end

        ::Trello::Card.create(card_opts)
      end
    end


    def find_label_ids_by_colors board_id, label_colors
      return [] if label_colors.blank?

      colors = CSV.parse_line(label_colors.to_s).map(&:strip)

      colors.reject! {|c| c.blank? || !::Trello::Label.label_colours.include?(c) }
      labels = []
      with_board(board_id) do |b|
        labels = b.labels
      end

      colors.map {|c| labels.find { |l| l.color == c }.try(:id) }.compact.uniq
    end

    def with_board board_id
      local_board = nil
      if @board && @board.id == board_id
        local_board = @board
      else
        @board = ::Trello::Board.find(board_id)
        local_board = @board
      end

      raise "Unable to find board id #{board_id}" if local_board.nil?

      yield local_board if local_board
    end


    def with_list board_id, list_name, raise_if_missing = false
      retval = nil
      with_board(board_id) do |b|
        list = b.lists.find {|lst| lst.name == list_name}
        raise "Unable to find a list named #{list_name} on the board #{b.name}" if list.nil? && raise_if_missing

        list = create_list!(b.id, list_name) unless list

        retval = yield list if list
      end
      retval
    end
    
    # create a list and return its ::Trello object
    def create_list! board_id, name, opts={}
      inner_opts = {board_id:board_id,name:name}
      inner_opts.merge!(opts)
      ::Trello::List.create(inner_opts)
    end

  end

end; end

# Monkey Patch for ruby-trello fixes bug preventing label usage.
# This can be removed when the PR on issue #172 from their github tracker 
# is merged and released.
# https://github.com/jeremytregunna/ruby-trello/issues/172

module Trello; class Card
  # Saves a record.
  #
  # @raise [Trello::Error] if the card could not be saved
  #
  # @return [String] The JSON representation of the saved card returned by
  #     the Trello API.
  def save
    # If we have an id, just update our fields.
    return update! if id

    client.post("/cards", {
      name:   name,
      desc:   desc,
      idList: list_id,
      idMembers: member_ids,
      idLabels: card_labels,
      pos: pos,
      due: due
    }).json_into(self)
  end
end; end;