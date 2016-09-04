module OpenChain; module Validator; class VariantLineIntegrityValidator < ActiveModel::Validator
  def validate line
    # we're ok if there isn't a variant
    return unless line.variant
    p = line.product
    if !p
      line.errors[:variant] << "must be on a line with an associated product."
      return
    end
    if line.product != line.variant.product
      line.errors[:variant] << " must be associated with same product as line."
      return
    end
  end
end; end; end
