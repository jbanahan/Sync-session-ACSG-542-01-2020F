require 'open_chain/custom_handler/group_support'

module OpenChain; module CustomHandler; module LumberLiquidators; module LumberGroupSupport
  GROUPS = {
    'MERCH'=>'Merchandising',
    'TRADECOMP'=>'Trade Compliance',
    'PRODUCTCOMP'=>'Product Compliance',
    'EXPRODUCTCOMP'=>'Executive Product Compliance',
    'SAPV'=>'SAP Vendor Management',
    'LEGAL'=>'Legal'
  }

  def self.included(base)
    base.extend(::OpenChain::CustomHandler::GroupSupport)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def prep_groups group_keys
      prep_group_objects group_keys, GROUPS
    end
  end
end; end; end; end
