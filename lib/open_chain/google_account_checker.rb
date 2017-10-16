require "open_chain/google_api_support"

module OpenChain
  class GoogleAccountChecker
    include OpenChain::GoogleApiSupport

    def self.run_schedulable(opts={})
      self.new.run
    end

    def run
      service = admin_directory_service

      suspended_users = []
      User.where("email like '%vandegriftinc.com' AND (disabled <> 1 OR disabled IS NULL) AND (system_user = 0 OR system_user IS NULL)").all.each do |user|
        email = user.email.gsub(/(.*?)(\+.*?)(@.*)/, '\1\3')
        response, suspended = user_suspended?(service, email)
        if suspended
          user.update_attribute(:disabled, suspended)
          suspended_users << user
          body = "The following account was disabled: #{email}<br><br>Debug Information:<br> #{response.to_json}".html_safe
          OpenMailer.send_simple_html(OpenMailer::BUG_EMAIL, "VFI Track Account Disabled: #{email}", body).deliver!
        end
        
      end

      suspended_users
    end

    private

      def user_suspended? service, email
        # my_customer is a keyword indicating to use the customer linked to the account querying the API
        response = service.list_users(customer: "my_customer", domain: "vandegriftinc.com", max_results: 1, query: "email='#{email}'")
        user = response.users.try(:first)
        return [response, (user.nil? || user.suspended?)]
      end
  end
end