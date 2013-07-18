module OpenChain::CustomHandler::AnnInc
  module AnnRelatedStylesSupport

    # Receives a row hash (as from the product generator's sync method) and explodes
    # it into one hash for each distinct related style, suitable to be passed into a preprocess row method/block.
    # Essentially this provides a shim to put in preprocess_row
    # opts takes result set indexes of where to find the unique identifier, missy, petite and tall style values
    def explode_lines_with_related_styles row, opts = {}
      local_opts = {:unique_identifier=>0, :missy=>(row.length - 3), :petite=>(row.length - 2), :tall=>(row.length - 1)}.merge opts
      rows_to_yield = []
      rows_to_yield << row

      # for each distinct missy/petite/tall style we have, we'll want to generate a new output row
      [local_opts[:missy], local_opts[:petite], local_opts[:tall]].each do |related_index|
        # don't create a new line if the style in the related style matches the unique identifier style or if the related style is blank
        related_style = row[related_index]
        unless related_style.blank? || related_style.upcase == row[local_opts[:unique_identifier]].upcase
          row_delta = row.dup
          row_delta[local_opts[:unique_identifier]] = row[related_index]
          rows_to_yield << row_delta
        end
      end

      rows_to_return = []
      rows_to_yield.each do |r|
        # Strip out the missy, petite, and tall columns
        r.delete local_opts[:missy]
        r.delete local_opts[:petite]
        r.delete local_opts[:tall]
        block_rows = yield r
        if block_rows
          block_rows.each {|ret_row| rows_to_return << ret_row}
        end
      end

      rows_to_return
    end
  end
end