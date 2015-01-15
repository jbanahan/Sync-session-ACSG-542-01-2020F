require 'rexml/document'
module OpenChain; module CustomHandler; module XmlHelper
  def est_time_str t
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"].at(t.to_i).strftime("%Y-%m-%d %H:%M %Z")
  end
  #get element text 
  # if force_blank_string then send "" instead of null
  def et parent, element_name, force_blank_string=false
    r  = parent.text(element_name)
    r = '' if r.nil? && force_blank_string
    r
  end
  
      
end; end; end