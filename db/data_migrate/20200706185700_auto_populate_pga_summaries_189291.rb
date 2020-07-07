class AutoPopulatePgaSummaries189291 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("Target")

    auto_populate_entry_pga_summaries
  end

  def down
    # Does nothing.
  end

  private

    def auto_populate_entry_pga_summaries
      entries = Entry.where("id NOT IN (SELECT entry_id FROM entry_pga_summaries)")
      entries.find_each do |ent|
        entry_pga_summary_data = Hash.new { |hash, key| hash[key] = 0 }

        ent.commercial_invoices.each do |inv|
          inv.commercial_invoice_lines.each do |cil|
            cil.commercial_invoice_tariffs.each do |tar|
              tar.pga_summaries.each do |pga|
                entry_pga_summary_data[pga.agency_code] += 1
              end
            end
          end
        end

        entry_pga_summary_data.each_key do |agency_code|
          ent.entry_pga_summaries.create!(agency_code: agency_code, summary_line_count: entry_pga_summary_data[agency_code])
        end
      end
    end
end