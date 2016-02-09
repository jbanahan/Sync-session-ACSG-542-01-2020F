require 'spec_helper'

describe OpenChain::CustomHandler::MassOrderCreator do
  subject do
    Class.new { include OpenChain::CustomHandler::MassOrderCreator }.new
  end

  let(:country) { Factory(:country) }
  let(:importer) {Factory(:importer)}
  let(:user) { Factory(:user, company: importer, product_view: true) }

  describe "create_orders" do

    let (:order_attributes) do 
      {ord_ord_num: "12345", ord_ord_date: "2016-02-01", ord_imp_id: importer.id, 
        order_lines_attributes: [
          {
            ordln_ordered_qty: 10,
            product: {
              prod_uid: "PROD123", prod_name: "Description", prod_imp_id: importer.id,
              classifications_attributes: [
                {
                  class_cntry_id: country.id, 
                  tariff_records_attributes: [
                    hts_hts_1: "1234567890"
                  ]
                }
              ]
            }
          }
        ]
      }
    end

    it "creates orders and products given an attribute hash keyed by model field values" do
      orders = subject.create_orders user, [order_attributes]
      expect(orders.length).to eq 1
      o = orders["12345"]
      expect(o.errors).to be_blank
      expect(o).to be_persisted

      o.reload
      expect(o.order_number).to eq "12345"
      expect(o.order_date).to eq Date.new(2016, 2, 1)
      expect(o.entity_snapshots.length).to eq 1

      expect(o.order_lines.length).to eq 1
      l = o.order_lines.first
      expect(l.quantity).to eq 10
      expect(l.product).not_to be_nil

      p = l.product
      expect(p.unique_identifier).to eq "PROD123"
      expect(p.importer).to eq importer
      expect(p.entity_snapshots.length).to eq 1
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.line_number).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
    end

    it "updates an existing order" do
      product = Factory(:product, importer: importer)
      order = Order.create! order_number: "12345", importer: importer
      order.order_lines.create! product: product, quantity: 20

      orders = subject.create_orders user, [order_attributes]
      expect(orders.length).to eq 1
      o = orders["12345"]
      expect(o.errors).to be_blank
      expect(o).to be_persisted

      o.reload
      expect(o.order_number).to eq "12345"
      expect(o.order_date).to eq Date.new(2016, 2, 1)
      expect(o.entity_snapshots.length).to eq 1

      expect(o.order_lines.length).to eq 2
      l = o.order_lines.first
      expect(l.quantity).to eq 20
      expect(l.product).to eq product

      l = o.order_lines.second
      expect(l.quantity).to eq 10
      expect(l.product).not_to be_nil

      p = l.product
      expect(p.unique_identifier).to eq "PROD123"
      expect(p.importer).to eq importer
      expect(p.entity_snapshots.length).to eq 1
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.line_number).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
    end

    it "does not create an order or product snapshot if existing order/product is unchanged" do
      product = Factory(:product, importer: importer, unique_identifier: "PROD123", name: "Description")
      classification = product.classifications.create! country: country, product: product
      tariff = classification.tariff_records.create! hts_1: 1234567890

      order = Order.create! order_number: "12345", importer: importer, order_date: "2016-02-01"
      order.order_lines.create! product: product, quantity: 10

      orders = subject.create_orders user, [order_attributes]
      o = orders['12345']

      expect(o.entity_snapshots.size).to eq 0
      expect(o.order_lines.first.product.entity_snapshots.size).to eq 0
    end

    it "works with custom fields" do
      # Even though this uses the UpdateModelFieldsSupport under the covers (which is designed and
      # and tested to work with custom fields), I'm still more comfortable adding in specific
      # checks here too.
      order_cf = CustomDefinition.create! module_type: 'Order', data_type: "string", label: "Order Test"
      order_line_cf = CustomDefinition.create! module_type: 'OrderLine', data_type: "string", label: "OrderLine Test"
      product_cf = CustomDefinition.create! module_type: 'Product', data_type: "string", label: "Product Test"

      order_attributes[order_cf.model_field_uid] = "Testing"
      order_attributes[:order_lines_attributes].first[order_line_cf.model_field_uid] = "Testing2"
      order_attributes[:order_lines_attributes].first[:product][product_cf.model_field_uid] = "Testing3"

      orders = subject.create_orders user, [order_attributes]
      o = orders['12345']
      expect(o.custom_value(order_cf)).to eq "Testing"
      expect(o.order_lines.first.custom_value(order_line_cf)).to eq "Testing2"
      expect(o.order_lines.first.product.custom_value(product_cf)).to eq "Testing3"
    end

    it "matches updates existing order lines by line number by default" do
      product = Factory(:product, importer: importer)
      order = Order.create! order_number: "12345", importer: importer
      order.order_lines.create! product: product, quantity: 20

      order_attributes[:order_lines_attributes].first[:ordln_line_number] = order.order_lines.first.line_number

      orders = subject.create_orders user, [order_attributes]
      o = orders['12345']
      expect(o.order_lines.length).to eq 1
      expect(o.order_lines.first.quantity).to eq 10
      expect(o.order_lines.first.product.unique_identifier).to eq "PROD123"
    end

    it "matches by product style if configured to do so" do
      product = Factory(:product, importer: importer)
      order = Order.create! order_number: "12345", importer: importer
      order_line = order.order_lines.create! product: product, quantity: 20

      order_attributes[:order_lines_attributes].first[:product][:prod_uid] = product.unique_identifier

      creater = Class.new do 
        include OpenChain::CustomHandler::MassOrderCreator
        def match_lines_method
          :ordln_puid
        end
      end.new

      orders = creater.create_orders user, [order_attributes]
      o = orders['12345']
      expect(o.order_lines.length).to eq 1
      expect(o.order_lines.first.quantity).to eq 10
      expect(o.order_lines.first.product.unique_identifier).to eq product.unique_identifier
    end

    it "destroys lines not referenced in attributes hash if configured to do so" do
      product = Factory(:product, importer: importer)
      order = Order.create! order_number: "12345", importer: importer
      order_line = order.order_lines.create! product: product, quantity: 20

      creater = Class.new do 
        include OpenChain::CustomHandler::MassOrderCreator
        def destroy_unreferenced_lines?
          true
        end
      end.new

      orders = creater.create_orders user, [order_attributes]
      o = orders['12345']
      expect(o.order_lines.length).to eq 1
      expect(o.order_lines.first.quantity).to eq 10
      expect(o.order_lines.first.product.unique_identifier).to eq "PROD123"
    end

    it "returns errors if encountered" do
      # Just pull out the product line, which will cause an error
      order_attributes[:order_lines_attributes].first.delete :product

      orders = subject.create_orders user, [order_attributes]
      o = orders['12345']
      expect(o.errors.full_messages).to include("Order lines product can't be blank")

      # We do expect the order to have been persisted, but it should only have the order number and importer in it
      expect(o).to be_persisted
      expect(o.order_number).to eq "12345"
      expect(o.importer).to eq importer
    end

    it "works without a single transaction" do
      # Not entirely sure how to determine this works correctly, since we do eventually utilize  
      # a transactional lock when saving (just not a blanket one over the whole order create/save).
      # For now, I'm just making sure the whole thing works.
      creater = Class.new do 
        include OpenChain::CustomHandler::MassOrderCreator
        def single_transaction_per_order?
          false
        end
      end.new

      orders = subject.create_orders user, [order_attributes]
      expect(orders.length).to eq 1
      o = orders["12345"]
      expect(o.errors).to be_blank
      expect(o).to be_persisted

      o.reload
      expect(o.order_number).to eq "12345"
      expect(o.order_date).to eq Date.new(2016, 2, 1)
      expect(o.entity_snapshots.length).to eq 1

      expect(o.order_lines.length).to eq 1
      l = o.order_lines.first
      expect(l.quantity).to eq 10
      expect(l.product).not_to be_nil

      p = l.product
      expect(p.unique_identifier).to eq "PROD123"
      expect(p.importer).to eq importer
      expect(p.entity_snapshots.length).to eq 1
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.country).to eq country
      expect(p.classifications.first.tariff_records.length).to eq 1
      expect(p.classifications.first.tariff_records.first.line_number).to eq 1
      expect(p.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
    end
  end
end