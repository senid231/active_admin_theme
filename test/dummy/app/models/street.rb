class Street < ActiveRecord::Base
  belongs_to :city

  def self.ransackable_attributes(_auth = nil)
    %w[name city_id]
  end

  def self.ransackable_associations(_auth = nil)
    []
  end

  def display_name = name
end
