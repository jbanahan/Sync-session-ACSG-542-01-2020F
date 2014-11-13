module OpenChain; module CustomHandler; module JJill; module JJillSupport
  UID_PREFIX = 'JJILL'

  def get_product_category_from_vendor_styles vendor_style_list
    r = 'Other'
    vals = vendor_style_list.collect {|v| v.to_s[0]}.uniq
    if vals.size != 1
      #do nothing, Other value already set
    elsif vals[0]=='K'
      r = 'Knit'
    elsif vals[0]=='W'
      r = 'Woven'
    elsif vals[0]=='S'
      r = 'Sweater'
    end
    return r
  end
end; end; end; end