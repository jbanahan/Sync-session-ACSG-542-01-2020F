module ConstantTextSupport
  extend ActiveSupport::Concern

  included do
    has_many :constant_texts, as: :constant_textable, dependent: :destroy, inverse_of: :constant_textable, autosave: true
  end

  def constant_text_for_date constant_text_type, reference_date: Time.zone.now.to_date
    return nil if reference_date.nil?

    # Reference date MUST be a date
    reference_date = reference_date.to_date

    texts = self.constant_texts.find_all do |t|
      t.text_type == constant_text_type && t.effective_date_start <= reference_date &&
        (t.effective_date_end.nil? || t.effective_date_end > reference_date)
    end

    if texts.length == 1
      texts.first
    else
      # Determine the result to use based on whichever one has a start date nearest to the reference date
      # The calculation below is a count of days between the two dates
      # Reference date should always be equal to or greater than the reference date - so we should never have
      # negative values we have to deal with
      texts.sort_by { |t| (reference_date - t.effective_date_start).to_i }.first
    end
  end
end