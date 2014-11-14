require 'digest/md5'

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

  def generate_order_fingerprint ord
    f = ""
    f << my_tos(ord.customer_order_number)
    f << my_tos(ord.vendor_id)
    f << my_tos(ord.mode)
    f << my_tos(ord.fob_point)
    f << my_tos(ord.factory_id)
    f << my_tos(ord.first_expected_delivery_date)
    f << my_tos(ord.ship_window_start)
    f << my_tos(ord.ship_window_end)
    ord.order_lines.each do |ol|
      f << my_tos(ol.quantity)
      f << my_tos(ol.price_per_unit)
      f << my_tos(ol.sku)
    end
    Digest::MD5.hexdigest f
  end

  private 
  def my_tos x
    x.blank? ? "_" : x.to_s
  end
end; end; end; end