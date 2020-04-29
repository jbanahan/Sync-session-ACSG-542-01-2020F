require 'open_chain/xml_builder'

module OpenChain; module CustomHandler; module Vandegrift; module KewillWebServicesSupport
  extend ActiveSupport::Concern
  include OpenChain::XmlBuilder

  def create_document action: "KC", category:, subAction:
    doc, xml = build_xml_document "requests"
    add_element(xml, "password", "lk5ijl9")
    add_element(xml, "userID", "kewill_edi")
    request = add_element(xml, "request")
    add_element(request, "action", action)
    add_element(request, "category", category)
    add_element(request, "subAction", subAction)
    kc_data = add_element(request, "kcData")

    [doc, kc_data]
  end

end; end; end; end;