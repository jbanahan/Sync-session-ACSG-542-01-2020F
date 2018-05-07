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
      :qualified_field_name => "(SELECT unique_identifier FROM products WHERE products.id = #{table_name}.product_id)",
      :data_type => :string
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
      :read_only => true,
      :data_type => :string
    }]
    r << [rank_start+2, "#{uid_prefix}_prod_id".to_sym, :product_id, "Product ID", {user_accessible: false, history_ignore: true,
      :import_lambda => lambda {|detail, data, user|
        product_id = data.to_i
        if detail.product_id != product_id && !(prod = Product.where(id: product_id).first).nil?
          detail.product  = prod if prod.can_view?(user)
        end
        ""
      },
      data_type: :integer
    }]
    r << [rank_start+3, "#{uid_prefix}_prod_ord_count".to_sym, :prod_ord_count, "Product Order Count", {
      history_ignore: true,
      read_only:true,
      export_lambda: lambda {|detail|
        ModelField.find_by_uid(:prod_order_count).process_export(detail.product,nil,true)
      },
      qualified_field_name: "(select count(*) from (select distinct order_lines.order_id, order_lines.product_id from order_lines) x where x.product_id = #{table_name}.product_id)",
      :data_type => :integer
    }]
    # I have no idea why there's 2 diffent fields for product id, but I'm afraid to remove one since they have conflicting setups (on is not read-only, one is history ignored)
    r << [rank_start+4, "#{uid_prefix}_prod_db_id".to_sym, :product_id, "Product DB ID", {read_only: true, user_accessible: false}]
    r << [rank_start+5, "#{uid_prefix}_prod_var_count".to_sym, :variant_count, "Product Variant Count",{
      read_only: true,
      data_type: :integer,
      history_ignore: true,
      qualified_field_name: "(SELECT count(*) FROM variants WHERE product_id = #{table_name}.id)",
      export_lambda: lambda {|detail|
        detail.product.variants.size
      }
    }]
    r
  end
end; end; end
