require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain
  module CustomHandler
    class PoloEfocusProductGenerator < ProductGenerator
      include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

      SYNC_CODE ||= 'efocus-product'

      def self.run_schedulable opts = {}
        self.new(opts).generate
      end

      def initialize opts = {}
        super(opts)
        @cdefs = self.class.prep_custom_definitions [:bartho_customer_id, :test_style, :set_type]
      end

      #Superclass requires this method
      def sync_code
        SYNC_CODE
      end

      def generate
        count = nil
        begin
          file = sync_xls
          ftp_file file if (count = self.row_count) > 0
        end while count > 0
      end

      def auto_confirm?
        false
      end

      def ftp_credentials
        {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ralph_Lauren/efocus_products"}
      end

      def query
        fields = [
          "products.id",
          cd_s(@cdefs[:bartho_customer_id].id),
          cd_s(2),
          "\"US\" as `#{ModelField.find_by_uid(:class_cntry_iso).label}`",
          cd_s(3),
          cd_s(4),
          "IFNULL(products.unique_identifier,\"\") AS `#{ModelField.find_by_uid(:prod_uid).label}`",
          cd_s(6),
          "IFNULL(products.name,\"\") AS `#{ModelField.find_by_uid(:prod_name).label}`",
          "\"\" AS `Blank 1`",
          cd_s(8),
          "IFNULL(tariff_records.hts_1,\"\") AS `#{ModelField.find_by_uid(:hts_hts_1).label}`",
          "IFNULL((SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_1 AND official_quotas.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_1_qc).label}`",
          "IFNULL((SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_1 AND official_tariffs.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_1_gr).label}`",
          "IFNULL(tariff_records.hts_2,\"\") AS `#{ModelField.find_by_uid(:hts_hts_2).label}`",
          "IFNULL((SELECT category FROM official_quotas WHERE official_quotas.hts_code = tariff_records.hts_2 AND official_quotas.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_2_qc).label}`",
          "IFNULL((SELECT general_rate FROM official_tariffs WHERE official_tariffs.hts_code = tariff_records.hts_2 AND official_tariffs.country_id = classifications.country_id),\"\") as `#{ModelField.find_by_uid(:hts_hts_2_gr).label}`",
          cd_s(9),
          cd_s(10),
          cd_s(11),
          cd_s(12),
          cd_s(13),
          cd_s(14),
          cd_s(15),
          cd_s(16),
          cd_s(17),
          cd_s(18),
          cd_s(19),
          cd_s(20),
          cd_s(21),
          cd_s(22),
          cd_s(23),
          cd_s(24),
          cd_s(25),
          cd_s(26),
          cd_s(27),
          cd_s(28),
          cd_s(29),
          cd_s(30),
          cd_s(31),
          cd_s(32),
          cd_s(33),
          cd_s(34),
          cd_s(35),
          cd_s(36),
          cd_s(37),
          cd_s(38),
          cd_s(39),
          cd_s(40),
          cd_s(41),
          cd_s(42),
          cd_s(43),
          cd_s(44),
          cd_s(45),
          cd_s(46),
          cd_s(47),
          cd_s(48),
          cd_s(49),
          cd_s(50),
          cd_s(51),
          cd_s(52),
          cd_s(53),
          cd_s(54),
          cd_s(55),
          cd_s(56),
          cd_s(57),
          cd_s(58),
          cd_s(59),
          cd_s(60),
          cd_s(61),
          cd_s(62),
          cd_s(63),
          cd_s(64),
          cd_s(65),
          cd_s(66),
          cd_s(67),
          cd_s(68),
          cd_s(69),
          cd_s(70),
          cd_s(71),
          cd_s(72),
          "\"\" AS `Blank 2`",
          cd_s(73),
          cd_s(74),
          cd_s(75),
          cd_s(76),
          "\"\" AS `Vendor Code`",
          cd_s(78),
          cd_s(79, boolean_y_n: true),
          cd_s(132),
          cd_s(137),
          cd_s(142),
          cd_s(147),
          cd_s(84),
          cd_s(102),
          cd_s(85),
          cd_s(86),
          cd_s(87),
          cd_s(88),
          cd_s(89),
          cd_s(90),
          cd_s(91),
          cd_s(92),
          cd_s(93),
          cd_s(94),
          cd_s(95),
          cd_s(@cdefs[:set_type].id)
        ]
        r = "SELECT #{fields.join(", ")}
FROM products
INNER JOIN classifications  on classifications.product_id = products.id
INNER JOIN countries countries on countries.iso_code = 'US' and classifications.country_id = countries.id
LEFT OUTER JOIN tariff_records tariff_records on tariff_records.classification_id = classifications.id
INNER JOIN custom_values cust_id ON products.id = cust_id.customizable_id AND cust_id.customizable_type = 'Product' and cust_id.custom_definition_id = #{@cdefs[:bartho_customer_id].id} and length(ifnull(rtrim(cust_id.string_value), '')) > 0
LEFT OUTER JOIN custom_values test_style ON products.id = test_style.customizable_id AND test_style.customizable_type = 'Product' and test_style.custom_definition_id = #{@cdefs[:test_style].id}
LEFT OUTER JOIN custom_values set_type ON classifications.id = set_type.customizable_id AND set_type.customizable_type = 'Classification' and set_type.custom_definition_id = #{@cdefs[:set_type].id}
INNER JOIN (#{inner_query}) inner_query ON inner_query.id = products.id
ORDER BY products.id, tariff_records.line_number
"
      end

      def inner_query
        # This query is here soley to allow us to do limits...it needs to be done as subquery like this because there can potentially be more than one row per product.
        # If we didn't do this, then there's the possibility that we chop off a tariff record from a query if we just added a limit to a single query.
        r = "SELECT distinct inner_products.id
FROM products inner_products
INNER JOIN classifications inner_classifications on inner_classifications.product_id = inner_products.id
INNER JOIN countries inner_countries on inner_countries.iso_code = 'US' and inner_classifications.country_id = inner_countries.id
LEFT OUTER JOIN tariff_records inner_tariff_records on inner_tariff_records.classification_id = inner_classifications.id
"

# The JOINS + WHERE clause below generates files that need to be synced
# && Have an HTS 1, 2, or 3 value OR are 'RL' Sets
# && have Barthco Customer IDs
# && DO NOT have a 'Test Style' value,
        if self.custom_where.blank?
          r += "#{Product.need_sync_join_clause(sync_code, 'inner_products')}
INNER JOIN custom_values inner_cust_id ON inner_products.id = inner_cust_id.customizable_id AND inner_cust_id.customizable_type = 'Product' and inner_cust_id.custom_definition_id = #{@cdefs[:bartho_customer_id].id} and length(ifnull(rtrim(inner_cust_id.string_value), '')) > 0
LEFT OUTER JOIN custom_values inner_test_style ON inner_products.id = inner_test_style.customizable_id AND inner_test_style.customizable_type = 'Product' and inner_test_style.custom_definition_id = #{@cdefs[:test_style].id}
LEFT OUTER JOIN custom_values inner_set_type ON inner_classifications.id = inner_set_type.customizable_id AND inner_set_type.customizable_type = 'Classification' and inner_set_type.custom_definition_id = #{@cdefs[:set_type].id}
WHERE #{Product.need_sync_where_clause('inner_products', Time.zone.now - 3.hours)}
AND (length(inner_tariff_records.hts_1) > 0 OR length(inner_tariff_records.hts_2) > 0 OR length(inner_tariff_records.hts_3) > 0 OR (inner_set_type.string_value = 'RL'))
AND (inner_test_style.string_value IS NULL OR length(rtrim(inner_test_style.string_value)) = 0)
"
        else
          r += self.custom_where
        end

        r += " ORDER BY inner_products.id ASC"
        r + " LIMIT #{max_results}"
      end

      def max_results
        5000
      end

    end
  end
end
