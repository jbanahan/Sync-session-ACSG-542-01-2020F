require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_related_styles_support'

module OpenChain
  module CustomHandler
    module AnnInc
      class AnnOhlProductGenerator < OpenChain::CustomHandler::ProductGenerator
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
        include OpenChain::CustomHandler::AnnInc::AnnRelatedStylesSupport

        SYNC_CODE ||= 'ANN-PDM'


        # SchedulableJob compatibility
        def self.run_schedulable opts={}
          self.generate opts
        end

        def self.generate opts={}
          g = self.new(opts)
          g.ftp_file g.sync_csv
        end

        def initialize(opts={})
          super(opts)
          @cdefs = self.class.prep_custom_definitions [:approved_date, :approved_long, :long_desc_override, :related_styles]
          @used_part_countries = []
          @row_buffer = []
        end

        # superclass requires this method
        def sync_code
          SYNC_CODE
        end

        def ftp_credentials
          ftp2_vandegrift_inc("to_ecs/Ann/OHL")
        end

        def sync_csv
          super(include_headers: false)
        end

        def auto_confirm?
          false
        end

        def preprocess_row outer_row, opts = {}
          # What we're doing here is buffering the outer_row values
          # until we see a new product id (or we're processing the last line).
          # This allows us to make sure we keep all the country values for
          # the same style number on consecutive rows while still exploding the related styles.
          rows = nil
          if opts[:last_result] || @row_buffer.empty? || @row_buffer.first[0] == outer_row[0]
            @row_buffer << outer_row
          end

          # No we need to determine if we need to drain the row buffer
          # Only do that if we got a new product record or if this is the last row in the export
          if opts[:last_result] || @row_buffer.first[0] != outer_row[0]
            # Use the hash so we ensure we're keeping all the rows for the same product grouped together
            exploded_rows = Hash.new {|h, k| h[k] = []}
            @row_buffer.each do |buffer_row|
              explode_lines_with_related_styles(buffer_row) do |row|
                pc_key = "#{row[0]}-#{row[4]}"
                local_row = [row]
                if @used_part_countries.include? pc_key
                  local_row = []
                else
                  @used_part_countries << pc_key
                end

                exploded_rows[row[0]] << local_row unless local_row.blank?
              end
            end

            rows = exploded_rows.values.flatten

            @row_buffer.clear
            # Now put the new record in the buffer
            @row_buffer << outer_row unless opts[:last_result]
          else
            # Because we're buffering the output in preprocess row, this causes a bit of issue with the sync method since no
            # output is returned sometimes.  This ends up confusing it and it doesn't mark the product as having been synced.
            # Even though rows for it will get pushed on a further iteration.  Throwing this symbol we can tell it to always
            # mark the record as synced even if no preprocess output is given
            throw :mark_synced
          end

          rows
        end

        def before_csv_write cursor, vals
          clean_string_values vals

          # ISO code must be uppercase
          vals[4].upcase!

          # replace the long description with the override value from the classification
          # unless the override is blank
          vals[1] = vals[5] unless vals[5].blank?

          # remove the long description override value
          vals.pop

          vals
        end

        def query
          fields = [
            'products.id',
            'products.unique_identifier',
            cd_s(@cdefs[:approved_long].id),
            'tariff_records.hts_1',
            'ifnull(tariff_records.schedule_b_1,"")',
            'classifications.iso_code',
            cd_s(@cdefs[:long_desc_override].id),
            cd_s(@cdefs[:related_styles].id),
          ]
          r = "SELECT #{fields.join(', ')}
FROM products
INNER JOIN (SELECT classifications.id, classifications.product_id, countries.iso_code
  FROM classifications
  INNER JOIN countries ON classifications.country_id = countries.id AND countries.iso_code IN (\"US\",\"CA\")
) as classifications on classifications.product_id = products.id
INNER JOIN tariff_records on tariff_records.classification_id = classifications.id and length(tariff_records.hts_1) > 0
#{Product.need_sync_join_clause(sync_code)}
INNER JOIN custom_values AS a_date ON a_date.custom_definition_id = #{@cdefs[:approved_date].id} AND a_date.customizable_id = classifications.id and a_date.date_value is not null
"
          w = "WHERE #{Product.where_clause_for_need_sync(sent_at_or_before: Time.zone.now - 8.hours)}"
          r << (@custom_where ? @custom_where : w)
          # US must be in file before Canada per OHL spec
          r << " ORDER BY products.id, classifications.iso_code DESC, tariff_records.line_number"
          r
        end
      end
    end
  end
end
