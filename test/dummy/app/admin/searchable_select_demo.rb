# Demo of the searchable select: the options endpoints, a form and a filter
# list that use them, paging (71 countries), and a dependent select (city
# follows country). The cities list filters by several countries.
ActiveAdmin.register Customer do
  searchable_select_options label: :name, search: :name_cont, order: :name, per_page: 10
end

ActiveAdmin.register Country do
  menu false
  filter :name
  searchable_select_options order: :name, per_page: 20
end

ActiveAdmin.register City do
  menu false
  filter :name
  filter :country, as: :searchable_select, min_chars: 0, multiple: true
  searchable_select_options order: :name, per_page: 20
end

ActiveAdmin.register Order do
  menu parent: "Demo pages", priority: 6
  permit_params :reference, :status, :customer_id, :country_id, :city_id

  filter :customer, as: :searchable_select, min_chars: 0
  filter :country, as: :searchable_select, min_chars: 0
  filter :city, as: :searchable_select, min_chars: 0, depends_on: :country_id_eq, depends_placeholder: "Select a country first"
  filter :status, as: :select, collection: Order::STATUSES

  index do
    selectable_column
    id_column
    column :reference
    column :customer
    column :country
    column :city
    column :status
    actions
  end

  form do |f|
    f.inputs do
      f.input :reference
      f.input :customer, as: :searchable_select, min_chars: 0, placeholder: "Search customers"
      f.input :country, as: :searchable_select, min_chars: 0
      f.input :city, as: :searchable_select, min_chars: 0, depends_on: :country_id, depends_placeholder: "Select a country first"
      f.input :status, as: :select, collection: Order::STATUSES
    end
    f.actions
  end
end
