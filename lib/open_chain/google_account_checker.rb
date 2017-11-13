require "open_chain/google_api_support"

module OpenChain
  class GoogleAccountChecker
    include OpenChain::GoogleApiSupport

    def self.run_schedulable(opts={})
      self.new.run
    end

    def run
      google_users = google_user_list()
      suspended_users = []
      User.where("email like '%vandegriftinc.com' AND (disabled <> 1 OR disabled IS NULL) AND (system_user = 0 OR system_user IS NULL)").all.each do |user|
        email = user.email.gsub(/(.*?)(\+.*?)(@.*)/, '\1\3')

        if google_users[email].nil?
          user.disabled = true
          user.save!

          suspended_users << user
        end
      end

      if suspended_users.length > 0
        OpenMailer.send_simple_html(OpenMailer::BUG_EMAIL, "VFI Track #{"Account".pluralize(suspended_users.length)} Disabled", email_body(suspended_users, MasterSetup.get.request_host)).deliver!
      end
      suspended_users
    end

    private

      def email_body users, system
        l = users.length

        body = "<p>The following #{"account".pluralize(l)} #{l > 1 ? "were" : "was"} disabled from #{system} because #{l > 1 ? "they" : "it"} #{l > 1 ? "were" : "was"} suspended or missing from Gmail:<ol>"
        users.each {|u| body << "<li>#{ERB::Util.html_escape u.username} - #{ERB::Util.html_escape u.email}</li>"}
        body << "</p>"

        body.html_safe
      end

      def google_user_list
        service = admin_directory_service
        users = {}
        service.fetch_all(items: :users, cache: false) do |token|
          service.list_users(page_token: token, customer: "my_customer", domain: "vandegriftinc.com", max_results: 100, query: "isSuspended=false", projection: "basic")
        end.each {|u| users[u.primary_email] = u}

        users
      end
  end
end