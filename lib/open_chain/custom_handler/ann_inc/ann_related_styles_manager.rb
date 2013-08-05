require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnRelatedStylesManager
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        AGGREGATE_FIELDS ||= [:po,:origin,:import,:cost,:dept_num,:dept_name]

        #expose these as readers for ease of testing
        attr_reader :related_cd, :aggregate_defs, :ac_date_cd, :approved_cd

        # Pass in a style and it's related styles and get back a single clean 
        # object with everything handled properly and the style / related styles
        # in the right place and persisted to the database
        def self.get_style base_style, missy, petite, tall
          c = self.new base_style, missy, petite, tall
          p = c.product_to_use c.find_all_styles
        end
        
        # don't call. Use the static get_style method
        def initialize base_style, missy, petite, tall
          @base = base_style
          @missy = missy
          @petite = petite
          @tall = tall
          @related_cd = prep_custom_definitions([:related_styles]).values.first
          @aggregate_defs = prep_custom_definitions AGGREGATE_FIELDS
          @ac_date_cd = prep_custom_definitions([:ac_date]).values.first
          @approved_cd = prep_custom_definitions([:approved_date]).values.first
        end

        #find all styles that could be a match
        def find_all_styles
          Product.
            joins("LEFT OUTER JOIN custom_values on custom_values.custom_definition_id = #{@related_cd.id} and custom_values.customizable_id = products.id").
            where("unique_identifier IN (:uid) 
              OR custom_values.text_value LIKE :base_like 
              OR custom_values.text_value LIKE :missy_like 
              OR custom_values.text_value LIKE :petite_like 
              OR custom_values.text_value LIKE :tall_like",
            {
              uid:[@base,@missy,@petite,@tall].collect{|b| make_no_match b},
              base_like:"%#{make_no_match @base}%",
              missy_like:"%#{make_no_match @missy}%",
              petite_like:"%#{make_no_match @petite}%",
              tall_like:"%#{make_no_match @tall}%"
            }).
            order('products.updated_at DESC')
        end

        # figure out which style to use as the base for modifications
        # and prepare it
        def product_to_use potential_styles
          m = missy_style
          related_value = related_styles_value
          uid_to_use = m.blank? ? @base : m
          p = nil
          case potential_styles.size
          when 0
            p = Product.create!(unique_identifier:uid_to_use)
          when 1
            p = potential_styles.first 
          else
            if !m.blank?
              p = potential_styles.find {|ps| ps.unique_identifier == m}
            end
            p = potential_styles.first unless p
          end
          p = Product.find p.id #reload from DB to clear read only flags
          p.update_attributes(unique_identifier:uid_to_use) unless p.unique_identifier==uid_to_use
          p.update_custom_value! @related_cd, related_value
          if potential_styles.size > 1
            merge_aggregate_values p, potential_styles
            set_earliest_ac_date p, potential_styles
            set_best_classifications p, potential_styles
            potential_styles.each do |ps|
              next if ps==p
              ps.reload #reload to break links to classifications that may have been moved
              ps.destroy
            end
          end
          return p
        end

        def set_best_classifications product_to_use, potentials
          #RULES:
          # 1) all approved classifications must have same tariffs or throw exception
          # 2) use the one with the latest approval date
          # 3) if multiple with latest approval date, use the one linked to the given product if possible
          # 4) if we reach this step use the one with the latest approval date and most recent updated_at
          # 5) if no approvals do nothing
          prods = [product_to_use] + potentials.to_a
          Country.import_locations.each do |c|
            approved_classifications = prods.collect {|p| p.classifications.find {|cls| cls.country_id == c.id && !cls.get_custom_value(@approved_cd).value.blank? ? c : nil}}.compact
            next if approved_classifications.blank?
            validate_tariffs_same! approved_classifications
            newest_approval_date_cls = approved_classifications.sort {|a,b| a.get_custom_value(@approved_cd).value <=> b.get_custom_value(@approved_cd).value}.reverse.first
            newest_approval_date = newest_approval_date_cls.get_custom_value(@approved_cd).value
            with_newest_approval_date = approved_classifications.collect {|cls| cls.get_custom_value(@approved_cd).value == newest_approval_date ? cls : nil}.compact
            to_use = with_newest_approval_date.find {|t| t.product == product_to_use}
            to_use = with_newest_approval_date.sort {|a,b| a.updated_at <=> b.updated_at}.reverse.first unless to_use
            existing = product_to_use.classifications.find {|cls| cls.country_id == c.id}
            if existing!=to_use
              existing.destroy
              to_use.product_id = product_to_use.id
              to_use.save!
              product_to_use.reload
            end
          end

        end

        def set_earliest_ac_date product_to_use, other_products 
          prods = other_products
          prods << product_to_use
          ac_date = prods.collect {|p| p.get_custom_value(ac_date_cd).value}.compact.sort.first
          product_to_use.update_custom_value! ac_date_cd, ac_date
        end
        
        def merge_aggregate_values product_to_use, other_products
          @aggregate_defs.values.each do |cd|
            cv = product_to_use.get_custom_value(cd)
            base_val = aggregate_to_array cv.value
            other_products.each do |p|
              next if p == product_to_use
              p_cv = aggregate_to_array p.get_custom_value(cd).value
              base_val = base_val + p_cv
            end
            base_val = base_val.compact.uniq.sort
            base_val.reverse! if cd==@aggregate_defs[:cost]
            cv.value = base_val.join("\n")
            cv.save!
          end
        end

        # return the missy style if it can be figured out, else nil
        def missy_style
          return @missy unless @missy.blank?
          return @base if !@petite.blank? && !@tall.blank?
          nil
        end

        def related_styles_value
          r = [@base,@missy,@petite,@tall].collect {|x| x.blank? ? nil : x}.compact
          m = missy_style
          if m
            r.delete m
          else
            r.delete @base
          end
          r.blank? ? '' : r.join("\n")
        end

        private
        #prevent any blank strings from getting into where clauses
        def make_no_match b
          b.blank? ? 'NOMATCH' : b.strip
        end

        def aggregate_to_array val
          val.blank? ? [] : val.split("\n")
        end

        def validate_tariffs_same! classifications
          base = make_tariff_array classifications.first
          classifications.each {|cls| raise "Cannot merge classifications with different tariffs." unless base==make_tariff_array(cls)}
        end

        def make_tariff_array cls
          cls.tariff_records.collect {|tr| {ln:tr.line_number,h1:tr.hts_1,h2:tr.hts_2,h3:tr.hts_3}}
        end
      end
    end
  end
end
