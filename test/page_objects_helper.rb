# Shared setup of the page-object tests: the browser, the theme's page objects
# and one page class per dummy page.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"
require "active_admin_theme/page_objects"

module Pages
  PO = ActiveAdminPageObjects
  Theme = ActiveAdminTheme::PageObjects

  class Dashboard < PO::Page
    set_url "/admin/dashboard"
  end

  class DeeperPage < PO::Page
    set_url "/admin/deeper_page"
  end

  class CustomerIndex < PO::Page
    set_url "/admin/customers{?query*}"

    section :table, PO::Table do
      column :selectable, ""
      column :id, "Id"
      column :name, "Name"
      column :email, "Email"
      column :country, "Country"
      column :status, "Status"
      column :balance, "Balance"
      column :notes, "Notes"
      column :created_at, "Created At"
      column :actions, ""
    end
    section :filters, PO::Filters
    section :scopes, PO::Scopes
    section :batch_actions, PO::BatchActions
    section :download_links, PO::DownloadLinks
  end

  class CustomerShow < PO::Page
    set_url "/admin/customers/{id}"

    section :attributes_table, PO::AttributesTable
    section :columns, Theme::Columns
    section :help, PO::Panel, :active_admin_sidebar, "help"
  end

  class CustomerForm < PO::Page
    set_url "/admin/customers{/id}{/action}"

    section :form, PO::Form
  end

  class OrderIndex < PO::Page
    set_url "/admin/orders{?query*}"

    section :table, PO::Table
    section :pagination, PO::Pagination
    section :filters, PO::Filters do
      filter :customer, "Customer", Theme::SearchableSelectFilter
      filter :country, "Country", Theme::SearchableSelectFilter
      filter :city, "City", Theme::SearchableSelectFilter
      filter :status, "Status", PO::SelectFilter
    end
  end

  class OrderForm < PO::Page
    set_url "/admin/orders{/id}{/action}"

    section :form, PO::Form do
      field :reference, "Reference", PO::Form::StringField
      field :customer, "Customer", Theme::SearchableSelectField
      field :country, "Country", Theme::SearchableSelectField
      field :city, "City", Theme::SearchableSelectField
      field :status, "Status", PO::Form::SelectField
    end
  end

  class CityIndex < PO::Page
    set_url "/admin/cities{?query*}"

    section :table, PO::Table
    section :filters, PO::Filters
  end

  class ShipmentIndex < PO::Page
    set_url "/admin/shipments{?query*}"

    section :table, PO::Table
    section :filters, PO::Filters
  end

  class ShipmentForm < PO::Page
    set_url "/admin/shipments{/id}{/action}"

    section :form, PO::Form
  end

  class Components < PO::Page
    set_url "/admin/components"
  end

  class ConfirmDialogs < PO::Page
    set_url "/admin/confirm_dialog"
  end

  class ColumnsDemo < PO::Page
    set_url "/admin/columns"
  end
end

class PageObjectsTestCase < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  Theme = ActiveAdminTheme::PageObjects

  def setup
    page.current_window.resize_to(1280, 900)
  end

  def teardown
    Capybara.reset_sessions!
  end

  def phone
    page.current_window.resize_to(390, 800)
  end
end
