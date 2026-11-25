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
