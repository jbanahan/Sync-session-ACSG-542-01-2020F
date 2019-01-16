require 'open_chain/custom_handler/lumber_liquidators/lumber_product_vendor_constant_text_uploader'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberProductVendorPatentStatementUploader < OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorConstantTextUploader

  def self.can_view? user
    MasterSetup.get.custom_feature?("Lumber Liquidators") && user.in_group?("PATENTASSIGN")
  end

  def cross_reference_description
    "Patent Statement"
  end

  def cross_reference_type
    DataCrossReference::LL_PATENT_STATEMENTS
  end

  def constant_text_type
    "Patent Statement"
  end

end; end; end; end