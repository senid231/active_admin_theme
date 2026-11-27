# Demo of the searchable select: the options endpoints, a form and a filter
# list that use them, paging (71 countries), and a dependent select (city
# follows country). The cities list filters by several countries. The
# dependent lab page shows several parents, an optional parent, a fill that
# selects its only option, and an endpoint that answers with a bare array.
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
  # One city a country, so a dependent select fills with a single option.
  searchable_select_options :capitals, scope: -> { City.where(id: City.group(:country_id).select("MIN(cities.id)")) }, order: :name
end

# Searches the country filter inside an OR grouping, as a filter plugin's
# "None" option does, so the search object no longer reports the values.
ActiveAdmin.register City, as: "GroupedCity" do
  menu false
  filter :country, as: :searchable_select, min_chars: 0, multiple: true

  controller do
    def apply_filtering(chain)
      q = params.fetch(:q, {}).permit(country_id_in: []).to_h
      ids = q.delete("country_id_in")
      q["g"] = [{"m" => "or", "country_id_in" => ids, "country_id_null" => "1"}] if ids.present?
      @search = chain.ransack(q)
      @search.result
    end
  end
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

ActiveAdmin.register_page "Dependent lab" do
  menu parent: "Demo pages", priority: 9

  # The shorter reply: a bare array whose items name the id `value`.
  page_action :bare_customers, method: :get do
    customers = Customer.where("name LIKE ?", "%#{params[:term]}%").order(:name).limit(5)
    render json: customers.map { |customer| {value: customer.id, text: customer.name} }
  end

  content do
    panel "Several parents" do
      active_admin_form_for Shipment.new, url: "#", html: {id: "lab-several"} do |f|
        f.inputs do
          f.input :country, as: :searchable_select, min_chars: 0, multiple: true
          f.input :insured
          f.input :city, as: :searchable_select, depends_on: %i[country_id insured], depends_param: {country_id: "q[country_id_in]", insured: "insured"},
                         depends_placeholder: "Pick countries first", load_all: true
          f.input :street, as: :searchable_select, depends_on: :city_id, depends_optional: true, load_all: true
        end
      end
    end

    panel "Auto select and a bare reply" do
      active_admin_form_for Order.new, url: "#", html: {id: "lab-auto"} do |f|
        f.inputs do
          f.input :country, as: :searchable_select, min_chars: 0
          f.input :city, as: :searchable_select, options_name: :capitals, depends_on: :country_id, load_all: true, auto_select_single: true
          f.input :customer, as: :searchable_select, url: "/admin/dependent_lab/bare_customers", min_chars: 0
        end
      end
    end
  end
end
