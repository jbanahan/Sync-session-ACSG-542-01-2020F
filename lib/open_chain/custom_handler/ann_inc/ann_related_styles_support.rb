module OpenChain::CustomHandler::AnnInc
  module AnnRelatedStylesSupport

    # Receives a row hash (as from the product generator's sync method) and explodes
    # it into one hash for each distinct related style, suitable to be passed into a preprocess row method/block.
    # Essentially this provides a shim to put in preprocess_row
    # opts takes result set indexes of where to find the unique identifier and related styles
    def explode_lines_with_related_styles row, opts = {}
      local_opts = {:unique_identifier=>0, :related=>(row.length - 1)}.merge opts
      rows_to_yield = []

      # for each distinct missy/petite/tall style we have, we'll want to generate a new output row
      uid = row[local_opts[:unique_identifier]]
      related = row[local_opts[:related]]
      row.delete local_opts[:related]
      rows_to_yield << row
      unless related.blank?
        related_array = related.split("\n")
        related_array.each do |rv|
          next if rv==uid || rv.blank?
          r = row.dup
          r[local_opts[:unique_identifier]] = rv
          rows_to_yield << r
        end
      end

      rows_to_return = []
      rows_to_yield.each do |r|
        block_rows = yield r
        if block_rows
          block_rows.each {|ret_row| rows_to_return << ret_row}
        end
      end

      rows_to_return
    end
  end
end
