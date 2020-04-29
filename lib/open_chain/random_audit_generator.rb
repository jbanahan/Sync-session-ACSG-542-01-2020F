module OpenChain; class RandomAuditGenerator

  # takes a random selection of records from array returned by SearchQuery#execute
  def self.run results, percent, record_type
    if record_type == "line"
      line_audit percent, results
    else
      header_audit percent, results
    end
  end

  def self.line_audit percent, results
    indexes = (0...results.count).to_a
    count = (indexes.count * (percent / 100.0)).round
    audit_indexes = choose (count.zero? ? 1 : count), indexes
    results.each_with_index.select { |*, i| audit_indexes.include? i }.map(&:first).deep_dup
  end

  def self.header_audit percent, results
    record_ids = results.map { |r| r[:row_key] }.uniq
    count = (record_ids.count * (percent / 100.0)).round
    audit_record_ids = choose (count.zero? ? 1 : count), record_ids
    results.select { |r| audit_record_ids.include? r[:row_key] }.deep_dup
  end

  def self.choose n, selection
    picked = []
    n.times do |nth|
      pick = selection[Random.rand(selection.count)]
      picked << selection.delete(pick)
    end
    picked
  end

end; end
