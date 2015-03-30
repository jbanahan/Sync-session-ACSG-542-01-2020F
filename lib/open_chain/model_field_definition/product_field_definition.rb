require 'open_chain/model_field_generator/country_hts_generator'
require 'open_chain/model_field_generator/region_generator'
module OpenChain; module ModelFieldDefinition; module ProductFieldDefinition
  include OpenChain::ModelFieldGenerator::CountryHtsGenerator
  include OpenChain::ModelFieldGenerator::RegionGenerator
  def add_product_fields
    add_fields CoreModule::PRODUCT, [
      [1,:prod_uid,:unique_identifier,"Unique Identifier",{:data_type=>:string}],
      [2,:prod_ent_type,:name,"Product Type",{:entity_type_field=>true,
        :import_lambda => lambda {|detail,data|
          if data.blank?
            return "#{ModelField.find_by_uid(:prod_ent_type).label} with name #{data} not found.  Field ignored."
          end

          et = EntityType.where(:name=>data).first
          if et
            detail.entity_type = et
            return "#{ModelField.find_by_uid(:prod_ent_type).label} set to #{et.name}."
          else
            return "#{ModelField.find_by_uid(:prod_ent_type).label} with name #{data} not found.  Field ignored."
          end
        },
        :export_lambda => lambda {|detail|
          et = detail.entity_type
          et.nil? ? "" : et.name
        },
        :qualified_field_name => "(SELECT name from entity_types where entity_types.id = products.entity_type_id)",
        :data_type=>:integer
      }],
      [3,:prod_name,:name,"Name",{:data_type=>:string}],
      [4,:prod_uom,:unit_of_measure,"Unit of Measure",{:data_type=>:string}],
      #5 and 6 are now created with the make_vendor_arrays method below, Don't use them.
      [7,:prod_status_name, :name, "Status", {
        :import_lambda => lambda {|detail,data|
          return "Statuses are ignored. They are automatically calculated."
        },
        :export_lambda => lambda {|detail| detail.status_rule.nil? ? "" : detail.status_rule.name },
        :qualified_field_name => "(SELECT name FROM status_rules WHERE status_rules.id = products.status_rule_id)",
        :data_type=>:string
      }],
      #9 is available to use
      [10,:prod_class_count, :class_count, "Complete Classification Count", {
        :import_lambda => lambda {|obj,data|
          return "Complete Classification Count was ignored. (read only)"},
        :export_lambda => lambda {|obj|
          r = 0
          obj.classifications.each {|c|
            r += 1 if c.tariff_records.length > 0
          }
          r
        },
        :qualified_field_name => "(SELECT COUNT(distinct pcc_cls.id) FROM classifications pcc_cls
          INNER JOIN tariff_records pcc_tr ON pcc_tr.classification_id = pcc_cls.id AND LENGTH( pcc_tr.hts_1 ) > 0 WHERE products.id = pcc_cls.product_id)",
        :data_type => :integer
      }],
      [11,:prod_changed_at, :changed_at, "Last Changed",{:data_type=>:datetime,:history_ignore=>true, read_only: true}],
      [13,:prod_created_at, :created_at, "Created Time",{:data_type=>:datetime,:history_ignore=>true, read_only: true}],
      [14,:prod_first_hts, :prod_first_hts, "First HTS Number", {
        :import_lambda => lambda {|obj,data| "First HTS Number was ignored, must be set at the tariff level."},
        :export_lambda => lambda {|obj|
          r = ""
          cls = obj.classifications.sort_classification_rank.first
          unless cls.nil?
            t = cls.tariff_records.first
            r = t.hts_1 unless t.nil?
          end
          r.nil? ? "" : r.hts_format
        },
        :qualified_field_name => "(select hts_1 from tariff_records fht inner join classifications fhc on fhc.id = fht.classification_id  where fhc.product_id = products.id and fhc.country_id = (SELECT id from countries ORDER BY ifnull(classification_rank,9999), iso_code ASC LIMIT 1) LIMIT 1)",
        :data_type=>:string,
        :history_ignore=>true
      }],
      [15,:prod_bom_parents,:bom_parents,"BOM - Parents",{
        :data_type=>:string,
        :import_lambda => lambda {|o,d| "Bill of Materials ignored, cannot be changed by upload."},
        :export_lambda => lambda {|product|
          product.parent_products.pluck(:unique_identifier).uniq.sort.join(",")
        },
        :qualified_field_name => "(select group_concat(distinct unique_identifier SEPARATOR ',') FROM bill_of_materials_links INNER JOIN products par on par.id = bill_of_materials_links.parent_product_id where bill_of_materials_links.child_product_id = products.id)"
      }],
      [16,:prod_bom_children,:bom_children,"BOM - Children",{
        :data_type=>:string,
        :import_lambda => lambda {|o,d| "Bill of Materials ignored, cannot be changed by upload."},
        :export_lambda => lambda {|product|
          product.child_products.pluck(:unique_identifier).uniq.sort.join(",")
        },
        :qualified_field_name => "(select group_concat(distinct unique_identifier SEPARATOR ',') FROM bill_of_materials_links INNER JOIN products par on par.id = bill_of_materials_links.child_product_id where bill_of_materials_links.parent_product_id = products.id)"
      }],
      [17, :prod_attachment_count, :attachment_count, "Attachment Count", {
        :import_lambda=>lambda {|obj,data| "Attachment Count ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.respond_to?(:all_attachments) ? obj.all_attachments.count : obj.attachments.count},
        :qualified_field_name=>"((select count(*) from attachments where attachable_type = 'Product' and attachable_id = products.id) + (select count(*) from linked_attachments where attachable_type = 'Product' and attachable_id = products.id))",
        :data_type=>:integer
      }],
      [18,:prod_max_component_count,:max_component_count, 'Component Count (Max)', {
        :import_lambda=>lambda {|o,d| "Component Count (Max) ignored. (read only)"},
        :export_lambda=>lambda {|o|
          max = 0
          o.classifications.each do |c|
            sz = c.tariff_records.size
            max = sz if sz && sz > max
          end
          max
        },
        :qualified_field_name => "(SELECT ifnull(max((select count(*) from tariff_records where tariff_records.classification_id = classifications.id)),0) from classifications where classifications.product_id = products.id)",
        :data_type=>:integer
      }],
      [19,:prod_ent_type_id,:entity_type_id,"Product Type",{:entity_type_field=>true, :user_accessible => false,
        :import_lambda => lambda {|detail,data|
          if data.blank?
            return "#{ModelField.find_by_uid(:prod_ent_type).label} with name #{data} not found.  Field ignored."
          end

          et = EntityType.where(:id=>data).first
          if et
            detail.entity_type = et
            return "#{ModelField.find_by_uid(:prod_ent_type).label} set to #{et.name}."
          else
            return "#{ModelField.find_by_uid(:prod_ent_type).label} with name #{data} not found.  Field ignored."
          end
        },
        :export_lambda => lambda {|detail|
          et = detail.entity_type
          et.nil? ? nil : et.id
        },
        :data_type=>:integer
      }],
    ]
    add_fields CoreModule::PRODUCT, make_last_changed_by(12,'prod',Product)
    add_fields CoreModule::PRODUCT, make_vendor_arrays(5,"prod","products")
    add_fields CoreModule::PRODUCT, make_division_arrays(100,"prod","products")
    add_fields CoreModule::PRODUCT, make_master_setup_array(200,"prod")
    add_fields CoreModule::PRODUCT, make_importer_arrays(250,"prod","products")
    add_fields CoreModule::PRODUCT, make_sync_record_arrays(300,'prod','products','Product')
    add_fields CoreModule::PRODUCT, make_attachment_arrays(400,'prod',CoreModule::PRODUCT)
    add_model_fields CoreModule::PRODUCT, make_country_hts_fields
    add_model_fields CoreModule::PRODUCT, make_region_fields
  end
end; end; end
