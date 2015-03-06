module OpenChain; module ModelFieldGenerator; module ProductGenerator
  def make_product_arrays(rank_start,uid_prefix,table_name)
    r = []
    r << [rank_start,"#{uid_prefix}_puid".to_sym, :unique_identifier,"Product Unique ID", {
      :import_lambda => lambda {|detail,data|
        return "Product not changed." if detail.product && detail.product.unique_identifier==data
        p = Product.where(:unique_identifier=>data).first
        return "Product not found with unique identifier #{data}" if p.nil?
        detail.product = p
        return "Product set to #{data}"
      },
      :export_lambda => lambda {|detail|
        if detail.product
          return detail.product.unique_identifier
        else
          return nil
        end
      },
      :qualified_field_name => "(SELECT unique_identifier FROM products WHERE products.id = #{table_name}.product_id)"
    }]
    r << [rank_start+1,"#{uid_prefix}_pname".to_sym, :name,"Product Name",{
      :import_lambda => lambda {|detail,data|
        "Product name cannot be set by import."
      },
      :export_lambda => lambda {|detail|
        if detail.product
          return detail.product.name
        else
          return nil
        end
      },
      :qualified_field_name => "(SELECT name FROM products WHERE products.id = #{table_name}.product_id)",
      :history_ignore => true,
      :read_only => true
    }]
    r << [rank_start+1, "#{uid_prefix}_prod_id".to_sym, :id,"Product Name", {user_accessible: false, history_ignore: true,
      :import_lambda => lambda {|detail, data, user|
        product_id = data.to_i
        if detail.product_id != product_id && !(prod = Product.where(id: product_id).first).nil?
          detail.product  = prod if prod.can_view?(user)
        end
        ""
      }
    }]
    r
  end
end; end; end
