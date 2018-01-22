# == Schema Information
#
# Table name: support_requests
#
#  id            :integer          not null, primary key
#  ticket_number :string(255)
#  body          :text
#  severity      :string(255)
#  referrer_url  :string(255)
#  user_id       :integer
#  external_link :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

require 'open_chain/trello'

class SupportRequest < ActiveRecord::Base
  belongs_to :user

  def send_request!
    self.class.request_sender.send_request(self)
    true
  end

  def self.request_sender
    return TestingSender.new if Rails.env.test?

    config = support_request_config
    raise "No ticket sender configured." if config.nil?

    config.keys.each do |key|
      sender = key.to_s.downcase

      if "trello" == sender
        config = config[key]
        return TrelloTicketSender.new(config['board_id'], config['list_name'], config['severity_colors'])
      elsif "email" == sender
        config = config[key]
        return EmailSender.new(config['addresses'])
      elsif "null" == sender
        return NullSender.new
      else
        raise "Unexpected Support Request ticket sender encountered: #{key}."
      end
    end
  end

  def self.support_request_config
    if defined?(@@config)
      return @@config
    else
      if File.exists?("config/support_request.yml")
        config = YAML.load_file("config/support_request.yml")
        if config && config.keys.size > 0
          @@config = config
          return @@config
        end
      else
        return nil
      end
    end
  end

  class TrelloTicketSender

    attr_reader :board_id, :list_name, :severity_mappings

    def initialize board_id, list_name, severity_mappings
      @board_id = board_id
      @list_name = list_name
      @severity_mappings = severity_mappings
    end

    def send_request support_request
      label_color = @severity_mappings[support_request.severity] if @severity_mappings.respond_to?(:[])
      card = OpenChain::Trello.send_support_request! @board_id, @list_name, support_request, label_color

      # Need to do this to generate the id, so we have an actual ticket number below in cases where 
      # the support request may not have been saved yet.
      if !support_request.persisted?
        support_request.save!
      end

      support_request.update_attributes! ticket_number: support_request.id.to_s, external_link: card.short_url
      support_request
    end
  end

  class EmailSender

    attr_reader :addresses

    def initialize addresses
      @addresses = addresses
    end

    def send_request support_request
      # Need to do this to generate the id, so we have an actual ticket number below in cases where 
      # the support request may not have been saved yet.
      if !support_request.persisted?
        support_request.save!
      end
      support_request.update_attributes! ticket_number: support_request.id.to_s
      OpenMailer.send_support_request_to_helpdesk(@addresses, support_request).deliver!
      support_request
    end

  end


  class NullSender

    def send_ticket support_ticket
      # black hole
    end
  end

  class TestingSender

    cattr_accessor :sent_requests
    
    def send_request support_request
      @@sent_requests ||= []

      # Need to do this to generate the id, so we have an actual ticket number below in cases where 
      # the support request may not have been saved yet.
      if !support_request.persisted?
        support_request.save!
      end

      support_request.update_attributes! ticket_number: support_request.id.to_s
      @@sent_requests << support_request
      support_request
    end
  end
end 
