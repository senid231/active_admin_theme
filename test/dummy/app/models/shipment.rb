class Shipment < ActiveRecord::Base
  CARRIERS = %w[Air Rail Road Sea].freeze
  PRIORITIES = %w[low high].freeze
  TAGS = %w[fragile oversize].freeze
  SIZES = %w[S M L].freeze

  belongs_to :product, optional: true
  belongs_to :country, optional: true
  belongs_to :city, optional: true
  belongs_to :street, optional: true
  has_many :parcels
  accepts_nested_attributes_for :parcels

  validates :carrier, presence: true

  def self.ransackable_attributes(_auth = nil)
    %w[reference product_id product_sku country_id city_id street_id carrier priority tag size insured]
  end

  def self.ransackable_associations(_auth = nil)
    %w[product country city street]
  end

  def display_name = reference
end
