require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/polo/polo_business_logic'

module OpenChain; module CustomHandler; module Polo
  # This class is solely for handling 850 XML documents intended to populate information into the VFI Track (Vandegrift)
  # application instance (.ie not RL one)
  class Polo850VandegriftParser
    include PoloBusinessLogic
    extend IntegrationClientParser

    def self.integration_folder
      "/opt/wftpserver/ftproot/www-vfitrack-net/_polo_850"
    end

    def self.parse data, opts = {}
      self.new(data).parse_dom
    end

    def initialize data
      @dom = REXML::Document.new data
    end

    def parse_dom 
      # The only thing we're doing here is finding the PO # and then extracting one of the Merchandise Division
      # lines from the details to save to the DataCrossReference table, so the SAP invoice generator will
      # have that cross reference to utilize when finding the profit center to bill.
      po_number = first_xpath_text "/Orders/MessageInformation/MessageOrderNumber"

      unless po_number.nil? || sap_po?(po_number)
        # Every line will have the same merchandise division so we only need to find a single one in the document
        merchandise_division = first_xpath_text "/Orders/Lines/ProductLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'MDV']/ItemCharacteristicsDescriptionCode"

        # If the 850 consisted solely of prepack lines then the Merchandise division is at the subline level
        unless merchandise_division
          merchandise_division = first_xpath_text "/Orders/Lines/ProductLine/SubLine/ProductDescriptions[ItemCharacteristicsDescriptionCodeDesc = 'MDV']/ItemCharacteristicsDescriptionCode"
        end

        if merchandise_division
          DataCrossReference.transaction do 
            cr = DataCrossReference.where(cross_reference_type: DataCrossReference::RL_PO_TO_BRAND, key: po_number).first_or_create! value: merchandise_division

            # I'm relying here on the save being a no-op in cases where we've created the cross-reference - since the value isn't dirty.
            cr.value = merchandise_division
            cr.save!
          end
        end
      end
    end

    private

      def first_xpath_text expression 
        text = nil
        node = REXML::XPath.first(@dom, expression)
        if node
          text = node.text
        end

        text
      end

  end
end; end; end;