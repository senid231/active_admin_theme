# Demo of the select features beyond the plain searchable select: the lazy
# defaults, a value other than the id, load-all, a three-level chain, and the
# plain selects the script upgrades on its own.
ActiveAdmin.register Product do
  menu false
  filter :name

  # All defaults: Product.search, newest first, 50 per page, typing three characters.
  searchable_select_options
  searchable_select_options :sku, value: :sku, label: ->(product) { "#{product.sku} #{product.name}" },
                                  apply_search: ->(scope, term) { scope.where("sku LIKE ?", "%#{term}%") },
                                  order: :sku, per_page: 20,
                                  additional_payload: ->(product) { {category: product.category} }
  searchable_select_options name: :by_category, scope: ->(params) { Product.where(category: params[:category]) },
                            allow_empty_search: false, text_attribute: :name
  searchable_select_options name: :legacy, scope: -> { Product.where(category: "toys") }, display_text: ->(product) { product.name.upcase },
                            filter: ->(term, scope) { scope.where(sku: term) }
end

ActiveAdmin.register Street do
  menu false
  filter :name
  searchable_select_options order: :name
end

ActiveAdmin.register Shipment do
  menu parent: "Demo pages", priority: 7
  permit_params :reference, :product_id, :product_sku, :country_id, :city_id, :street_id, :carrier, :priority, :tag, :size, :insured,
                parcels_attributes: [:kind]

  filter :reference
  filter :product, as: :searchable_select
  filter :product_sku_eq, as: :searchable_select, label: "Product SKU", resource: Product, options_name: :sku
  filter :country, as: :searchable_select, min_chars: 0
  filter :city, as: :searchable_select, min_chars: 0, depends_on: :country_id_eq
  filter :street, as: :searchable_select, depends_on: :city_id_eq, load_all: true
  filter :carrier, as: :select, collection: Shipment::CARRIERS
  filter :tag_eq, as: :select, label: "Tag", collection: proc { Shipment::TAGS | [params.dig(:q, :tag_eq)].compact_blank },
                  tom_select: {create: true, persist: false}
  filter :size, as: :select, collection: Shipment::SIZES, tom_select: false
  filter :insured

  # A String name keeps its case; a Symbol name is titlecased.
  sidebar "Estimated spend", only: :show do
    para "Sentence case, as written."
  end
  sidebar :quick_notes, only: :show do
    para "Titlecased."
  end
  sidebar "translated one", only: :show do
    para "Named by I18n."
  end

  index do
    id_column
    column :reference
    column :product
    column :product_sku
    column :city
    column :street
    column :carrier
    column :tag
    actions
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :reference
      f.input :product, as: :searchable_select
      f.input :product_sku, as: :searchable_select, resource: Product, options_name: :sku, per_page: 10
      f.input :country, as: :searchable_select, min_chars: 0
      # Three cities a country and two a page: load-all has to fetch two pages.
      f.input :city, as: :searchable_select, depends_on: :country_id, load_all: true, per_page: 2
      f.input :street, as: :searchable_select, depends_on: :city_id, load_all: true
      f.input :carrier, as: :select, collection: Shipment::CARRIERS
      f.input :priority, as: :select, include_blank: "None", collection: Shipment::PRIORITIES, tom_select: {allowEmptyOption: true}
      f.input :tag, as: :select, collection: Shipment::TAGS | [f.object.tag].compact_blank, tom_select: {create: true, persist: false}
      f.input :size, as: :select, collection: Shipment::SIZES, tom_select: false
      f.input :insured
    end
    f.has_many :parcels do |parcel|
      parcel.input :kind, as: :select, collection: Parcel::KINDS
    end
    f.actions
  end
end

# Selects outside the filters and forms, and selects added after the page loaded.
ActiveAdmin.register_page "Select lab" do
  menu parent: "Demo pages", priority: 8

  content do
    panel "Outside a form" do
      div id: "lab-explicit" do
        select "data-tom-select": "true" do
          %w[Red Green Blue].each { |color| option color }
        end
      end
      div id: "lab-plain" do
        select do
          %w[Red Green Blue].each { |color| option color }
        end
      end
    end

    panel "Added later" do
      text_node <<~HTML.html_safe
        <template id="lab-template">
          <form class="formtastic"><ol><li class="select input"><select name="later"><option value=""></option><option>One</option><option>Two</option></select></li></ol></form>
        </template>
        <button type="button" id="lab-add" onclick="document.getElementById('lab-target').append(document.getElementById('lab-template').content.cloneNode(true))">Add a select</button>
        <div id="lab-target"></div>
      HTML
    end
  end
end
