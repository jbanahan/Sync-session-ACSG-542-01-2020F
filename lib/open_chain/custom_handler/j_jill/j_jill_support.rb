module OpenChain; module CustomHandler; module JJill; module JJillSupport
  UID_PREFIX = 'JJILL'

  def get_product_category_from_vendor_styles vendor_style_list
    r = 'Other'
    vals = vendor_style_list.collect {|v| 
      return nil if v.blank?
      return nil unless v.length >= 3
      v[0,3]
    }.uniq.compact
    return 'Other' if vals.blank?
    return 'Multi' if vals.length > 1
    cat = vals[0]
    return 'Other' unless cat.match /^[a-zA-Z]{3}/
    return cat
  end
end; end; end; end