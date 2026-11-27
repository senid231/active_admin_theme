# A composite primary key, as mobile network codes have.
class NetworkCode < ActiveRecord::Base
  self.primary_key = %i[mcc mnc]

  def code
    "#{mcc}-#{mnc}"
  end

  def self.ransackable_attributes(_auth = nil)
    %w[mcc mnc name]
  end
end
