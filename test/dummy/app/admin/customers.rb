# DB-backed resource: index with filters and batch actions, show, and a form.
ActiveAdmin.register Customer do
  permit_params :name, :email, :country, :status, :balance, :notes
  config.batch_actions = true

  scope :all, default: true
  scope(:active) { |customers| customers.where(status: "active") }

  member_action :secret, method: :get do
    render json: {value: "token-#{resource.id}"}
  end

  # Exact-id search: "id:3", or "#customer3@example.com" by the email value.
  searchable_select_options :by_id, scope: -> { Customer.where.not(status: "closed") }, label: :name, search: :name_cont, id_search: true
  searchable_select_options :by_email, value: :email, label: :name, search: :name_cont, id_search: "#"

  filter :name
  filter :email
  filter :country
  filter :status, as: :select, collection: Customer::STATUSES
  filter :balance
  filter :created_at

  index do
    selectable_column
    id_column
    column :name
    column :email
    column :country
    column(:status) { |customer| status_tag customer.status }
    column :balance
    column(:notes) { |customer| truncate_text customer.notes, length: 20 }
    column :created_at
    actions
  end

  sidebar "Help", only: :show do
    para "Sidebar content shows inside a panel."
  end

  related_records_sidebar priority: 20 do |customer|
    link "Orders", admin_orders_path(q: {customer_id_eq: customer.id}),
      count: Order.where(customer_id: customer.id), if: -> { authorized?(:read, Order) }
    link "Paid orders", admin_orders_path(q: {customer_id_eq: customer.id, status_eq: "paid"}), if: -> { customer.status == "active" }
  end

  external_links_sidebar priority: 30 do |customer|
    link "Billing", "https://billing.example/customers/#{customer.id}"
    link "Mail", "https://mail.example/search?q=#{CGI.escape(customer.email)}"
  end

  # Variants of the link groups, each shown by ?links=<name> on a show page.
  link_variant = ->(name) { -> { params[:links] == name } }

  related_records_sidebar title: "Many links", priority: 50, if: link_variant.("many") do |customer|
    link "Overview", "/admin/customers/#{customer.id}"
    group "Shipping" do
      link "Parcels", "/admin/orders", count: Order.where(customer_id: customer.id)
      link "Labels", "/admin/orders", count: -> { Order.where(customer_id: customer.id, status: "paid") }
      link "Returns", "/admin/orders"
    end
    group "Billing" do
      link "Invoices", "/admin/orders", count: 7
      link "Payments", "/admin/orders", count: -> { nil }
    end
  end

  related_records_sidebar title: "Few links", priority: 50, if: link_variant.("few") do
    group "Shipping" do
      link "Parcels", "/a"
      link "Labels", "/b"
    end
    group "Billing" do
      link "Invoices", "/c"
      link "Payments", "/d"
    end
  end

  related_records_sidebar title: "One group", priority: 50, if: link_variant.("single") do
    group "Billing" do
      6.times { |i| link "Item #{i + 1}", "/item/#{i + 1}" }
    end
  end

  related_records_sidebar title: "Headings on", priority: 50, group_headings: true, if: link_variant.("on") do
    link "Overview", "/overview"
    group("Shipping") { link "Parcels", "/a" }
    group("Billing") { link "Invoices", "/b" }
  end

  related_records_sidebar title: "Headings off", priority: 50, group_headings: false, if: link_variant.("off") do
    group("Shipping") { 3.times { |i| link "Parcel #{i + 1}", "/parcel/#{i + 1}" } }
    link "Overview", "/overview"
    group("Billing") { 3.times { |i| link "Invoice #{i + 1}", "/invoice/#{i + 1}" } }
  end

  related_records_sidebar title: "Hidden group", priority: 50, group_headings: true, if: link_variant.("hidden") do
    link "Overview", "/overview"
    group("Secret") { link "Vault", "/vault", if: -> { false } }
    group("Open") { link "Door", "/door" }
  end

  # No link shows for a customer that is not closed, so the sidebar is left out.
  external_links_sidebar title: "Closed accounts", priority: 40 do |customer|
    link "Archive", "https://archive.example/customers/#{customer.id}", if: -> { customer.status == "closed" }
  end

  show do
    columns "1:2" do
      column do
        attributes_table do
          row :name
          row :email
          row :country
          row(:status) { status_tag resource.status }
          row(:balance) { text_node with_tooltip(resource.balance, "Current balance") }
          row(:token) { secret_reveal url: "/admin/customers/#{resource.id}/secret" }
          row :created_at
        end
      end
      column do
        tabs do
          tab "Notes" do
            panel("Notes") { para resource.notes }
          end
          tab "Raw" do
            text_node pre_wrap(resource.attributes.map { |name, value| "#{name}: #{value}" }.join("\n"))
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :email
      f.input :country, as: :string
      f.input :status, as: :select, collection: Customer::STATUSES
      f.input :balance
      f.input :notes
    end
    f.actions
  end
end
