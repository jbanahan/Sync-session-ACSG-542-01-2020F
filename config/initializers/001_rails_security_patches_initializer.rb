# This monkey-patches the fix for CVE-2020-5267 (https://github.com/rails/rails/security/advisories/GHSA-65cv-r6x7-79hv)
# Which not being backported to 4.2 series.  It fixes a potential XSS vulnerability.

# Releases 5.2.5.2 and 6.0.2.2 have the fixes deployed..so the monkey patch is not required for them.
if Rails::VERSION::MAJOR == 4 || 
    (Rails::VERSION::MAJOR == 5 && Rails::VERSION::MINOR <= 2 && Rails::VERSION::TINY <= 4 && Rails::VERSION::PRE.to_i < 2) || 
    (Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR <= 0 && Rails::VERSION::TINY <= 2 && Rails::VERSION::PRE.to_i < 2) 

  ActionView::Helpers::JavaScriptHelper::JS_ESCAPE_MAP.merge!(
    {
      "`" => "\\`",
      "$" => "\\$"
    }
  )

  module ActionView::Helpers::JavaScriptHelper
    alias :old_ej :escape_javascript
    alias :old_j :j

    def escape_javascript(javascript)
      javascript = javascript.to_s
      if javascript.empty?
        result = ""
      else
        result = javascript.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"']|[`]|[$])/u, JS_ESCAPE_MAP)
      end
      javascript.html_safe? ? result.html_safe : result
    end

    alias :j :escape_javascript
  end
end