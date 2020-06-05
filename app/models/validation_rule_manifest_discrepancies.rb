# -*- SkipSchemaAnnotations

class ValidationRuleManifestDiscrepancies < BusinessValidationRule
  def run_validation(entry)
    # We want to grab the most recent manifest entry just in case previous comments were incorrect.
    latest_manifest_entry = entry.entry_comments.where("body like '% MnQty:%' and body like '% Qty:%'").order("generated_at DESC, id DESC").first

    return nil if latest_manifest_entry.blank?

    mn_qty, qty = extract_quantities(latest_manifest_entry)
    bill_of_lading = extract_bill_of_lading(latest_manifest_entry)

    if qty != mn_qty
      "Bill of Lading #{bill_of_lading} Quantity of #{qty} does not match Manifest Quantity of #{mn_qty}."
    else
      nil
    end
  end

  private

  def extract_bill_of_lading(comment)
    comment.body.match(/^.\s+(.+)\s+Qty:/).captures.first.to_s.gsub(" ", "")
  end

  def extract_quantities(comment)
    # If we reach this point, there is still a possibility that the regex may not match (IE missing quantities)
    # If this is the case we just return two 0s, and consider it a passing test.
    matches = comment.body.match(/Qty: (\d+) .*MnQty: (\d+)/)
    matches.present? ? matches.captures : [0, 0]
  end
end