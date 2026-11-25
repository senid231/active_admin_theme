require_relative "application"

# SQLite file rebuilt at every boot, so there is nothing to migrate. A file, not
# ":memory:": each Puma thread would get its own empty in-memory database.
require "fileutils"
db_file = File.expand_path("../tmp/dummy.sqlite3", __dir__)
FileUtils.mkdir_p(File.dirname(db_file))
FileUtils.rm_f(db_file)

Dummy::Application.initialize!

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :customers do |t|
    t.string :name, :email, :country, :status
    t.decimal :balance, precision: 12, scale: 2, default: 0
    t.text :notes
    t.timestamps
  end
  create_table :countries do |t|
    t.string :name
  end
  create_table :cities do |t|
    t.string :name
    t.references :country
  end
  create_table :streets do |t|
    t.string :name
    t.references :city
  end
  create_table :products do |t|
    t.string :name, :sku, :category
  end
  create_table :shipments do |t|
    t.string :reference, :product_sku, :carrier, :priority, :tag, :size
    t.boolean :insured, default: false
    t.references :product, :country, :city, :street
  end
  create_table :parcels do |t|
    t.string :kind
    t.references :shipment
  end
  create_table :orders do |t|
    t.string :reference, :status
    t.references :customer, :country, :city
    t.timestamps
  end
end

countries = %w[UK US NL DE FR UA PL]
30.times do |i|
  Customer.create!(
    name: "Customer #{i + 1}",
    email: "customer#{i + 1}@example.com",
    country: countries[i % countries.size],
    status: Customer::STATUSES[i % Customer::STATUSES.size],
    balance: (i * 137.5) % 5000,
    notes: "Note for customer #{i + 1}. " * 3
  )
end

# 70 countries and 3 cities each: enough rows for the searchable select to page.
# The last country has markup in its name to check that labels are escaped.
country_records = Array.new(70) { |i| Country.create!(name: format("Country %02d", i + 1)) }
country_records << Country.create!(name: %(<i>Italic</i> & "Quoted"))
country_records.each do |country|
  3.times { |i| City.create!(name: "#{country.name} City #{i + 1}", country: country) }
end

# Two streets per city of the first ten countries, for the country, city,
# street chain. 120 products: more than two pages of the default 50.
City.where(country_id: country_records.first(10).map(&:id)).find_each do |city|
  2.times { |i| Street.create!(name: "#{city.name} Street #{i + 1}", city: city) }
end
120.times do |i|
  Product.create!(name: format("Product %03d", i + 1), sku: format("SKU-%03d", 500 - i), category: Product::CATEGORIES[i % 2])
end
4.times do |i|
  city = country_records[4].cities.order(:id).first
  Shipment.create!(
    reference: format("SHP-%02d", i + 1),
    product: Product.find(i + 1),
    product_sku: Product.find(i + 1).sku,
    country: country_records[4],
    city: city,
    street: city.streets.first,
    carrier: Shipment::CARRIERS[i],
    size: Shipment::SIZES[i % 3],
    insured: i.even?
  )
end

customers = Customer.order(:id).to_a
60.times do |i|
  country = country_records[i % 70]
  Order.create!(
    reference: format("ORD-%03d", i + 1),
    status: Order::STATUSES[i % Order::STATUSES.size],
    customer: customers[i % customers.size],
    country: country,
    city: country.cities.first
  )
end
