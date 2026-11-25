class Parcel < ActiveRecord::Base
  KINDS = %w[box envelope pallet].freeze

  belongs_to :shipment
end
