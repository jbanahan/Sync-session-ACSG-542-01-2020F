rack_release = Rack.release.split(".").map(&:to_i)

if rack_release[0] == 1
  module Rack
    class Request
      # This is a simple patch / backport of the change issued for this advisory: https://nvd.nist.gov/vuln/detail/CVE-2020-8184
      # This fix was not backported to the 1.6 branch yet (if it ever even will be).
      def cookies
        hash   = @env["rack.request.cookie_hash"] ||= {}
        string = @env["HTTP_COOKIE"]

        return hash if string == @env["rack.request.cookie_string"]
        hash.clear

        # According to RFC 6265:
        # The syntax for cookie headers only supports semicolons
        # User Agent -> Server ==
        # Cookie: SID=31d4d96e407aad42; lang=en-US
        string.split(/[;] */n).each_with_object(hash) do |cookie, cookies|
          next if cookie.empty?
          key, value = cookie.split('=', 2)
          cookies[key] = (Rack::Utils.unescape(value) rescue value) unless cookies.key?(key) # rubocop:disable Style/RescueModifier
        end

        @env["rack.request.cookie_string"] = string
        hash
      end
    end
  end
end