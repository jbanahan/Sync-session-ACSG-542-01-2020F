class ProductTradePreferenceProgram < ActiveRecord::Base
  belongs_to :product, inverse_of: :product_trade_preference_programs
  belongs_to :trade_preference_program, inverse_of: :product_trade_preference_programs

  def can_view? user
    return false unless self.product && self.trade_preference_program
    return self.product.can_view?(user) && self.trade_preference_program.can_view?(user)
  end
end
