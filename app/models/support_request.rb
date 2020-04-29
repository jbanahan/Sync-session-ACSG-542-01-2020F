# == Schema Information
#
# Table name: support_requests
#
#  body          :text(65535)
#  created_at    :datetime         not null
#  external_link :string(255)
#  id            :integer          not null, primary key
#  referrer_url  :string(255)
#  severity      :string(255)
#  ticket_number :string(255)
#  updated_at    :datetime         not null
#  user_id       :integer
#

class SupportRequest < ActiveRecord::Base
  attr_accessible :body, :external_link, :referrer_url, :severity,
    :ticket_number, :user_id, :user

  belongs_to :user

  def send_request!
    self.class.request_sender.send_request(self)
    true
  end

  def self.request_sender
    return TestingSender.new if test_env?

    config = support_request_config
    raise "No ticket sender configured." if config.nil?

    config.each_key do |key|
      sender = key.to_s.downcase

      if "email" == sender
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
    MasterSetup.secrets["support_request"]
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
      OpenMailer.send_support_request_to_helpdesk(@addresses, support_request).deliver_now
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

  def self.test_env?
    Rails.env.test?
  end
  private_class_method :test_env?
end
