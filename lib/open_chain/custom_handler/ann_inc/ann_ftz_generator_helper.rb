module OpenChain; module CustomHandler; module AnnInc; module AnnFtzGeneratorHelper

  def initialize opts={}
    settings = {"public_key_path" => "config/ann-integration-point.asc"}.merge(opts)
    super(settings)
    @row_buffer = []
    @gpg = OpenChain::GPG.new settings["public_key_path"]
  end

  def sync_csv
    super(include_headers: false, use_raw_values: true, csv_opts: {col_sep: "|"})
  end

  def generate file_stem
    r_count = nil
    file_count = 0
    now = timestamp.delete("T")
    begin
      file = sync_csv || Tempfile.new(["blank", ".txt"])
      file_count += 1
      # At least one file should be sent, even if it's blank
      if (r_count = self.row_count) > 0 || (file_count == 1)
        encrypt_file(file) { |enc_file| ftp_file enc_file, remote_file_name: "#{file_stem}#{now}#{suffix(file_count)}.txt.gpg" }
        file.close
      end
    end while r_count > 0
  end

  def preprocess_row outer_row, opts = {}
    # What we're doing here is buffering the outer_row values
    # until we see a new product id (or we're processing the last line).
    # This allows us to keep related styles on consecutive rows.
    outer_row = remap(outer_row)
    rows = nil
    if opts[:last_result] || @row_buffer.empty? || @row_buffer.first[-1] == outer_row[-1]
      @row_buffer << outer_row
    end
    if opts[:last_result] || @row_buffer.first[-1] != outer_row[-1]
      # Use the hash so we ensure we're keeping all the rows for the same product grouped together
      exploded_rows = Hash.new {|h, k| h[k] = []}
      @row_buffer.each { |buffer_row| explode_lines buffer_row, exploded_rows }
      
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

  def timestamp
    Time.zone.now.in_time_zone("America/New_York").strftime("%Y%m%dT%H%M%S")
  end

  def suffix n
    (n > 1) ? "_v#{n}" : ""
  end

  def encrypt_file source_file
    Tempfile.open(["ann_bom", ".dat"]) do |f|
      f.binmode
      @gpg.encrypt_file source_file, f
      yield f
    end
  end

  def us
    Country.where(iso_code: "US").first
  end

  # Second gsub covers edge case where \r\n gets truncated
  def clean_description descr
    return nil unless descr.present?
    descr.gsub(/\r?\n/, " ").gsub(/\r/, "")
  end

end; end; end; end
