# Browser test (headless Chrome): the page objects of the searchable select
# drive the widget in a form and in the filters.
require_relative "page_objects_helper"

class PageObjectsSearchableSelectTest < PageObjectsTestCase
  def new_order
    Pages::OrderForm.new.tap { |form_page| form_page.load(action: "new") }.form
  end

  def test_fields_and_filters_are_detected_without_a_declaration
    cities = Pages::CityIndex.new
    cities.load
    assert_instance_of Theme::SearchableSelectFilter, cities.filters.filter(:country)
    customer = Pages::CustomerForm.new
    customer.load(action: "new")
    assert_instance_of ActiveAdminPageObjects::Form::SelectField, customer.form.field(:status)

    form_page = Class.new(ActiveAdminPageObjects::Page) do
      set_url "/admin/orders/new"
      section :form, ActiveAdminPageObjects::Form
    end.new
    form_page.load
    assert_instance_of Theme::SearchableSelectField, form_page.form.field(:customer)
    assert_instance_of ActiveAdminPageObjects::Form::SelectField, form_page.form.field(:status)
  end

  def test_declared_fields_match_the_form
    form = new_order
    assert form.has_exact_fields?
    assert_instance_of Theme::SearchableSelectField, form.field(:customer)
  end

  def test_field_picks_an_option_and_the_form_submits_it
    form = new_order
    form.fill(reference: "ORD-PO-1", customer: "Customer 17", country: "Country 05", city: "Country 05 City 2", status: "paid")
    assert_equal "Customer 17", form.field(:customer).selected
    assert_equal ["Customer 17"], form.field(:customer).chosen
    refute form.field(:customer).open?
    form.submit
    order = Order.find_by!(reference: "ORD-PO-1")
    assert_equal ["Customer 17", "Country 05", "Country 05 City 2"], [order.customer.name, order.country.name, order.city.name]
  end

  def test_field_searches_with_another_text
    form = new_order
    form.field(:customer).fill("Customer 23", search: "23")
    assert_equal "Customer 23", form.field(:customer).selected
    # Without a search the option has to be on the first page.
    form.field(:country).choose("Country 03", search: false)
    assert_equal "Country 03", form.field(:country).selected
  end

  def test_field_lists_the_offered_options
    customer = new_order.field(:customer)
    assert_equal Customer.order(:name).limit(10).pluck(:name), customer.options
    assert customer.open?
    customer.search("Customer 3")
    assert customer.has_no_option?("Customer 1")
    assert_equal ["Customer 3", "Customer 30"], customer.options
    customer.close
    refute customer.open?
  end

  def test_field_clears_its_value
    form_page = Pages::OrderForm.new
    form_page.load(id: 1, action: "edit")
    customer = form_page.form.field(:customer)
    assert_equal ["Customer 1"], customer.chosen
    customer.remove("Customer 1")
    assert_empty customer.chosen
    assert_nil customer.selected

    customer.fill("Customer 4")
    customer.fill(nil)
    assert_empty customer.chosen
  end

  def test_field_placeholder_and_disabled_state
    form = new_order
    assert_equal "Search customers", form.field(:customer).placeholder
    assert_equal "Select a country first", form.field(:city).placeholder
    assert form.has_disabled_field?(:city)
    assert form.has_enabled_field?(:customer)
    assert form.field(:city).disabled?

    form.field(:country).fill("Country 05")
    assert form.has_enabled_field?(:city)
    assert_equal ["Country 05 City 1", "Country 05 City 2", "Country 05 City 3"], form.field(:city).options
  end

  def test_filter_picks_an_option_and_filters_the_index
    index = Pages::OrderIndex.new
    index.load
    customer = index.filters.filter(:customer)
    customer.select_option("Customer 17")
    assert customer.has_item?("Customer 17")
    assert customer.has_selected?("Customer 17")
    assert customer.has_no_item?("Customer 1")
    index.filters.submit
    assert index.table.has_rows?(count: Order.where(customer_id: 17).count)
    assert index.filters.filter(:customer).has_item?("Customer 17")
    assert index.filters.has_declared_filters?
  end

  def test_filter_offers_options_in_the_open_dropdown
    index = Pages::OrderIndex.new
    index.load
    customer = index.filters.filter(:customer)
    customer.open
    assert customer.has_option?("Customer 1")
    customer.search("Customer 30")
    assert customer.has_option?("Customer 30")
    assert customer.has_no_option?("Customer 1")
    customer.close
  end

  def test_dependent_filter_is_disabled_until_its_parent_has_a_value
    index = Pages::OrderIndex.new
    index.load
    city = index.filters.filter(:city)
    assert city.has_disabled?
    index.filters.filter(:country).select_option("Country 05")
    assert city.has_no_disabled?
    city.select_option("Country 05 City 1")
    index.filters.submit
    assert index.table.has_rows?(count: 1)
  end

  # A multiple select keeps its dropdown open after a pick; left open, it
  # covers the submit button below the filter.
  def test_multiple_filter_picks_removes_and_submits
    cities = Pages::CityIndex.new
    cities.load
    country = cities.filters.filter(:country)
    country.select_option("Country 05", search: "05")
    country.select_option("Country 06")
    country.select_option("Country 07")
    assert_equal ["Country 05", "Country 06", "Country 07"], country.chosen
    refute country.open?
    country.remove("Country 06")
    assert country.has_no_item?("Country 06")
    cities.filters.submit
    assert cities.table.has_rows?(count: 6)
    assert_equal ["Country 05", "Country 07"], cities.filters.filter(:country).chosen

    cities.filters.filter(:country).clear
    assert_empty cities.filters.filter(:country).chosen
  end
end
