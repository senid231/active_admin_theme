class Product < ActiveRecord::Base
  CATEGORIES = %w[tools toys].freeze

  # What searchable_select_options searches with when it is given no search:.
  def self.search(term)
    where("name LIKE :term OR sku LIKE :term OR name || ' (' || sku || ')' LIKE :term", term: "%#{sanitize_sql_like(term)}%")
  end

  def self.ransackable_attributes(_auth = nil)
    %w[name sku category]
  end

  def self.ransackable_associations(_auth = nil)
    []
  end

  def display_name = "#{name} (#{sku})"
end
