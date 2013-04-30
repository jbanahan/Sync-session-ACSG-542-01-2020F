require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    #process bill of materials report from Polo SAP and associate products
    class PoloSapBomHandler

      def initialize custom_file
        @custom_file = custom_file
      end

      def can_view? user
        user.edit_products?
      end

      def process user

        #read the excel file and build hash of mappings
        x = OpenChain::XLClient.new @custom_file.attached.path
        last_row_number = x.last_row_number 0
        last_parent_id = nil
        last_parent_style = nil
        children = []
        parent_mapping = {}
        (1..last_row_number).each do |n|
          h = x.get_row_as_column_hash 0,n
          parent_style = h[0]['value']
          plant_code = h[2]['value']
          parent_id = "#{parent_style}~#{plant_code}"
          next if parent_style.blank?
          if parent_id != last_parent_id
            parent_mapping[last_parent_style] = children unless children.empty?
            children = []
          end
          children << {:style=>h[4]['value'],:quantity=>h[6]['value']}
          last_parent_id = parent_id
          last_parent_style = parent_style
        end
        parent_mapping[last_parent_style] = children unless children.empty?

        #write mappings
        parent_count = 0
        parent_mapping.each do |parent,children_array|
          parent_count += 1
          Product.transaction do
            p = Product.where(:unique_identifier=>parent).first_or_create!
            p.bill_of_materials_children.destroy_all
            children_array.each do |ch|
              c = Product.where(:unique_identifier=>ch[:style]).first_or_create!
              p.bill_of_materials_children.create!(:child_product_id=>c.id,:quantity=>ch[:quantity])
            end
          end
        end
        msg_body = "
File #{@custom_file.attached_file_name} has completed.<br /><br />
#{parent_count} products were updated.<br /><br />
You can download the update file <a href='/custom_features/polo_sap_bom/'>here</a>."
        user.messages.create(:subject=>"Bill of Materials Update Complete",:body=>msg_body)
      end
    end
  end
end
