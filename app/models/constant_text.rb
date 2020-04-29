# == Schema Information
#
# Table name: constant_texts
#
#  constant_text          :string(255)      not null
#  constant_textable_id   :integer          not null
#  constant_textable_type :string(255)      not null
#  created_at             :datetime         not null
#  effective_date_end     :date
#  effective_date_start   :date             not null
#  id                     :integer          not null, primary key
#  text_type              :string(255)      not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  idx_constant_textable_id_and_constant_textable_type  (constant_textable_id,constant_textable_type)
#

# This class exists as a way to give a particular core object a "constant" text value for a specific range of time.
# What this is currently being used for is to determine some sort of notice to add to a particular purchase order
# based on the effective constant texts associated with the vendor.
#
# So, by looking up the vendor and determining the effective text to use based on the order date, that allows us to create
# a sliding window of notices/text values associated with the vendor for display on the order - without having to harcode
# these values into a parser.
class ConstantText < ActiveRecord::Base
  attr_accessible :constant_text, :constant_textable_id, :constant_textable_type, :effective_date_end, :effective_date_start, :text_type

  belongs_to :constant_textable, polymorphic: true, inverse_of: :constant_texts

  validates :constant_text, :effective_date_start, :text_type, presence: true

end
