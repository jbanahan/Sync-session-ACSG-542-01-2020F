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

    list = ApiWrapper.find_or_create_list_by_name!(VFI_TRACK_PRIORITY_BOARD_ID,'Feedback')

    ApiWrapper.create_card! list.id, card_name, desc: card_description

    nil
  end

  #############
  #
  # Methods that work with the API directly are below
  # 
  # these generally should not be used outside of this class as 
  # it leaks the abstraction from the underlying gem
  #
  #############
  class ApiWrapper

    # configure the client on class load
    
    ::Trello.configure do |config|
      config.developer_public_key = OpenChain::Trello::DEV_PUB_KEY
      config.member_token = OpenChain::Trello::MEMBER_TOKEN
    end

    # create a card and return its ::Trello obj
    def self.create_card! list_id, name, opts={}
      inner_opts = {list_id:list_id,name:name}
      inner_opts.merge!(opts)
      ::Trello::Card.create(inner_opts)
    end

    # create a list and return its ::Trello object
    def self.create_list! board_id, name, opts={}
      inner_opts = {board_id:board_id,name:name}
      inner_opts.merge!(opts)
      ::Trello::List.create(inner_opts)
    end

    # find a list in the given board and return it
    def self.find_list_by_name board_id, name
      ::Trello::Board.find(board_id).lists.find {|list| list.name == name}
    end

    def self.find_or_create_list_by_name! board_id, name, create_opts={}
      list = find_list_by_name(board_id, name)
      list = create_list!(board_id,name,create_opts) if list.nil?
      return list
    end
  end
end; end