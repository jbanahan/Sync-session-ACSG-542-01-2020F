require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour; module UaSitesSubsHelper
  include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
  extend ActiveSupport::Concern
  included { include UnderArmourCustomDefinitionSupport; extend ClassMethods }
    
    module ClassMethods
      def process opts={}
        g = self.new(opts)
        g.sync_csv(csv_opts: {row_sep: "\r\n"})
      end
    end

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions [:prod_site_codes]
    end

    def products
      @products ||= Product.includes(:classifications => [:country, :tariff_records])
    end

    def site_countries
      @site_countries ||= Country.where(european_union: true).pluck(:iso_code).concat ["US", "CA", "HK", "PA"]
    end
    
    def ftp_credentials
      {server: 'transfer.underarmour.com', username: 'ftpvandegrift', password: 'k1mbIXyu', protocol: "sftp"}
    end
end; end; end; end;