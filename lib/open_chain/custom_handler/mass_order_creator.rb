module OpenChain; module CustomHandler; module MassOrderCreator
  extend ActiveSupport::Concern

  def create_orders user, order_attribute_arrays
    Creator.new(self).create_orders user, order_attribute_arrays
  end

  def single_transaction_per_order?
    # In some cases where there's a TON of lines per order we don't really want to do a single transaction per
    # order.  It's just too taxing on the system.  If that's the case, override this method
    # to return false and a transaction will be made per product creation and then a transaction will be 
    # run for the order lookup/creation and then another for the actual line updates.
    true
  end

  def match_lines_method
    # If ordln_line_number, this will use the line_number attribute to determine which existing line 
    # the order line attributes may belong to.

    # If ordln_puid or prod_uid, then the product style will be utilized

    # If no value is given, it's assumed no updating of existing lines will be done.
    :ordln_line_number
  end

  def destroy_unreferenced_lines?
    # If true, this will remove EVERY line from an order that is not included as part of the given 
    # attribute array.  You ONLY want to use this if you're sure you're getting full orders sent.
    false
  end

  # This method can be overriden if you want to provide a different method for finding which order_line a set of 
  # order_line_attributes belongs to.
  def find_existing_order_line_for_update order, order_line_attributes
    # Name is intentionally long/obscure to prevent accidental override
    order_line = nil
    if match_lines_method.to_s == 'ordln_line_number'
      line_number = order_line_attributes['ordln_line_number']
      # If line number is blank, we're going to assume that all lines are new
      if !line_number.blank?
        order_line = order.order_lines.find {|ol| ol.line_number == line_number.to_i }
      end
    elsif ['ordln_puid', 'prod_uid'].include? match_lines_method.to_s
      style = order_line_attributes['ordln_puid']
      # Style can't be blank and if it is, it'll fail a product presence validation later, so just ignore this issue for now.
      if !style.blank?
        order_line = order.order_lines.find {|ol| ol.product.try(:unique_identifier) == style }
      end
    end

    order_line
  end

  # Inner class used as means of making create_order internals private
  class Creator
    def initialize caller
      @caller = caller
    end

    def create_orders user, order_attribute_arrays
      # For each order, first create all the linked products, then come back to create the order.
      orders = {}

      order_attribute_arrays.each do |order_attributes|
        # Find the order (creating if needed)
        order_attributes = order_attributes.with_indifferent_access

        find_order(user, order_attributes) do |order|
          orders[order.order_number] = order
          break unless order.errors.blank?

          used_order_lines = Set.new
          order_lines = order_attributes['order_lines_attributes'].presence || []
          order_lines.each do |order_line_attributes|
            product_attributes = order_line_attributes.delete 'product'
            if product_attributes

              # Pull down the ordln_puid (if present) to the product level
              # if there's no unique_identifier present on the product line
              if product_attributes['prod_uid'].blank? && !order_attributes['ordln_puid'].blank?
                product_attributes['prod_uid'] = order_attributes['ordln_puid']
              end

              product = find_and_create_product(product_attributes, user)
              if product.errors.size > 0
                order.errors[:base].push *product.errors.full_messages
                break
              else
                # By replacing the ordln_puid attribute with the ordln_prod_id one, we gain both lookup performance
                # on attribute import as well as making this a no-op on updates where the order lines haven't changed
                # to a different product (update conditions would always result in a lookup if ordln_puid was used).
                order_line_attributes['ordln_prod_id'] = product.id
                order_line_attributes['ordln_puid'] = product.unique_identifier

                order_line = @caller.find_existing_order_line_for_update(order, order_line_attributes)

                # Don't need this any longer, since we determine which product belongs to the line and did the line matching,
                # leaving it in causes multiple product lookups since both ordln_prod_id and ordln_puid would both do product lookups
                # when only one is needed.
                order_line_attributes.delete 'ordln_puid'
                if order_line
                  used_order_lines << order_line.id
                  order_line_attributes['id'] = order_line.id
                end
              end
            end
          end

          # I'm choosing to not rollback the transaction here.  Largely because all we've done at this point is
          # just create supporting products and the actual order (header), which will need to be present in the system anyway 
          # for this order to get reloaded (once data is fixed) so there's no real point in rolling back
          break unless order.errors.blank?

          # At this point, add destroy order line attributes that will remove any line in the order that is NOT referenced in 
          # order line attributes.
          if @caller.destroy_unreferenced_lines?
            order_lines_to_destroy = order.order_lines.find_all {|ol| !used_order_lines.include?(ol.id) }
            order_lines_to_destroy.each do |ol|
              if !ol.shipping?
                order_lines << {'id' => ol.id, "_destroy" => true}
              end
            end
          end
          
          # At this point, we can use the attributes hash to insert the data into the order
          if @caller.single_transaction_per_order?
            apply_attributes_and_save(order, order_attributes, user)
          else
            Lock.with_lock_retry(order) do
              apply_attributes_and_save(order, order_attributes, user)
            end
          end
        end
      end

      orders
    end

    def find_order user, order_attributes
      order = nil
      Lock.acquire("Order-#{order_attributes['ord_ord_num']}") do 
        order = Order.where(order_number: order_attributes['ord_ord_num']).first

        if order.nil?
          order_attrs = build_new_order_attributes(order_attributes)
          order = Order.new
          if order.assign_model_field_attributes(order_attrs, user: user)
            order.save
          end
        end
      end

      if order.persisted? && @caller.single_transaction_per_order?
        Lock.with_lock_retry(order) do
          yield order
        end
      else
        yield order
      end
    end

    def find_and_create_product product_attributes, user
      product = nil
      Lock.acquire("Product-#{product_attributes['prod_uid']}") do 
        product = Product.where(unique_identifier: product_attributes['prod_uid']).first_or_create!
      end

      Lock.with_lock_retry(product) do
        apply_attributes_and_save(product, product_attributes, user)
      end

      product
    end

    def build_new_order_attributes order_attributes
      new_attributes = {}
      # These are all the keys related to the order attributes that are required when creating an order object
      ['ord_ord_num', 'ord_imp_id', 'ord_imp_syscode', 'ord_imp_name', 'ord_ven_id', 'ord_ven_syscode', 'ord_ven_name'].each do |key|
        new_attributes[key] = order_attributes.delete(key) if order_attributes[key]
      end

      new_attributes
    end

    def apply_attributes_and_save obj, obj_attributes, user
      if obj.assign_model_field_attributes(obj_attributes, user: user) && changed?(obj)
        if obj.save
          # Load all custom values to optimize snapshot speed
          obj.freeze_all_custom_values_including_children
          obj.create_snapshot(user)
        end
      end
    end


    def changed? obj
      # Apparently we can't rely on the "changed?" flag in active record to accurately report if anything other than the object
      # itself has changed - .ie order.changed? can't tell if any order lines have changed.
      CoreModule.walk_object_heirarchy(obj) {|cm, object| return true if object.changed?}
      false
    end


  end
end; end; end;