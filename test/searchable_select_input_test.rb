# The selected options a searchable_select input renders into the page. No
# browser.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"

class SearchableSelectInputTest < Minitest::Test
  # Hides Customer 17 from reading, the way a scoping adapter (CanCan, Pundit) would.
  class HidingAdapter < ActiveAdmin::AuthorizationAdapter
    def authorized?(_action, _subject = nil)
      true
    end

    def scope_collection(collection, _action = ActiveAdmin::Auth::READ)
      collection = collection.all
      collection.klass == Customer ? collection.where.not(name: "Customer 17") : collection
    end
  end

  def page(path)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.get path
    assert_equal 200, session.response.status
    Nokogiri::HTML(session.response.body)
  end

  def options(html, name)
    html.css("select[name='#{name}'] option").map { |option| [option.text, option["value"]] }
  end

  def with_adapter(adapter)
    namespace = ActiveAdmin.application.namespace(:admin)
    previous = namespace.authorization_adapter
    namespace.authorization_adapter = adapter
    yield
  ensure
    namespace.authorization_adapter = previous
  end

  def test_selected_option_shows_the_label
    customer = Customer.find_by!(name: "Customer 17")
    html = page("/admin/orders?q[customer_id_eq]=#{customer.id}")
    assert_includes options(html, "q[customer_id_eq]"), ["Customer 17", customer.id.to_s]
  end

  def test_selected_option_outside_the_read_scope_keeps_the_value_but_not_the_label
    customer = Customer.find_by!(name: "Customer 17")
    with_adapter(HidingAdapter) do
      html = page("/admin/orders?q[customer_id_eq]=#{customer.id}")
      assert_includes options(html, "q[customer_id_eq]"), [customer.id.to_s, customer.id.to_s]
      refute_includes html.css("select[name='q[customer_id_eq]']").text, "Customer 17"
    end
  end

  def test_values_searched_inside_a_grouping_stay_selected
    countries = Country.order(:id).first(2)
    query = countries.map { |country| "q[country_id_in][]=#{country.id}" }.join("&")
    html = page("/admin/grouped_cities?#{query}")
    selected = options(html, "q[country_id_in][]")
    countries.each { |country| assert_includes selected, [country.name, country.id.to_s] }
  end

  def test_dependent_options_render_as_data_attributes
    html = page("/admin/dependent_lab")
    data = ->(name, key) { html.at_css("select[name='#{name}']")["data-searchable-select-#{key}"] }

    parents = [{"name" => "shipment[country_id]", "param" => "q[country_id_in]"}, {"name" => "shipment[insured]", "param" => "insured"}]
    assert_equal parents, JSON.parse(data.("shipment[city_id]", "parents"))
    assert_nil data.("shipment[city_id]", "parent-name")
    assert_nil data.("shipment[city_id]", "parent-optional")

    assert_equal "shipment[city_id]", data.("shipment[street_id]", "parent-name")
    assert_equal "q[city_id_eq]", data.("shipment[street_id]", "parent-param")
    assert_equal "true", data.("shipment[street_id]", "parent-optional")
    assert_nil data.("shipment[street_id]", "parents")
    assert_nil data.("shipment[street_id]", "auto-select")

    assert_equal "true", data.("order[city_id]", "auto-select")
    assert_nil data.("shipment[country_id][]", "parents")
  end

  def test_callable_value_raises
    page("/admin/shipments/new")
    sources = ActiveAdmin.application.namespace(:admin).resource_for(Product).searchable_select_sources
    sku = sources[:sku]
    sources[:sku] = sku.merge(value: ->(product) { product.sku })
    show_exceptions = Rails.application.env_config["action_dispatch.show_exceptions"]
    Rails.application.env_config["action_dispatch.show_exceptions"] = :none
    session = ActionDispatch::Integration::Session.new(Rails.application)
    error = assert_raises(ActionView::Template::Error) { session.get "/admin/shipments/new" }
    assert_match(/value: must be an attribute/, error.message)
  ensure
    Rails.application.env_config["action_dispatch.show_exceptions"] = show_exceptions
    sources[:sku] = sku
  end
end
