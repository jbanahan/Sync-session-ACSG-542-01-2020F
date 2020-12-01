class UpdateSearchSetupDownloadFormat < ActiveRecord::Migration
  def up
    # This migration can be removed once the xslx code is live..it should never be run again

    # We don't want to change the download format of any existing searches, people might be sending them to some other system 
    # etc, so we don't want that to break.  Since the format on the search_setups has been ignored since the new search 
    # was added, we're going to update everything to xls.  Going forward, new searches default to xlsx.
    if ActiveRecord::Base.connection.data_source_exists? 'search_setups'
      execute "UPDATE search_setups SET download_format = 'xls' WHERE download_format IS NULL OR download_format = '' OR download_format = 'csv'"
    end
  end

  def down
  end
end
