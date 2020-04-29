# This patch is required to force Rails into creating new tables using the MySQL Barracuda table format.
# This is required in order to use UTF-8 and retain the 255 character default string limit and still be
# able to index string columns.  This is due to Barracuda's support for longer (wider) index lengths
#
# TL;DR - This resolves errors of 'Mysql2::Error: Index column size too large. The maximum column size is 767 bytes.'
# when creating indexes that include string columns.
# See - https://github.com/rails/rails/issues/9855
require 'open_chain/database_utils'

if OpenChain::DatabaseUtils.primary_database_configuration["encoding"].to_s =~ /utf8/
  if ActiveRecord::VERSION::MAJOR < 5
    ActiveSupport.on_load :active_record do
      module ActiveRecord::ConnectionAdapters
        class AbstractMysqlAdapter
          def create_table_with_innodb_row_format(table_name, options = {})
            table_options = options.reverse_merge(:options => 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC')

            create_table_without_innodb_row_format(table_name, table_options) do |td|
             yield td if block_given?
            end
          end
          alias_method_chain :create_table, :innodb_row_format
        end
      end
    end
  else
    # This is supposedly fixed at some point (I think Rails 6)...but Rails 5 requires a different patch (see rails issue linked above)
    # This patch also appears to not be needed if using MySQL 5.7 as well.
    raise "Verify that ActiveRecord >= 5 correctly creates MySQL tables using ROW_FORMAT=DYNAMIC to support UTF-8."
  end
end