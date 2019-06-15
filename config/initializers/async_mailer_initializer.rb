if Rails::VERSION::MAJOR < 5
  class ActionMailer::DeliveryJob
    queue_as :default
  end
else
  raise "Add the following to application.rb to configure the default mailer queue: config.action_mailer.deliver_later_queue_name = 'default'"
end