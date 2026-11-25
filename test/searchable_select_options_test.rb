# The JSON endpoints of searchable_select_options: the reply, the options and
# the names accepted from other gems. No browser.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"

class SearchableSelectOptionsTest < Minitest::Test
  def get(path, params = {})
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.get path, params: params
    assert_equal 200, session.response.status
    JSON.parse(session.response.body)
  end

  def test_reply_has_results_and_pagination
    reply = get("/admin/products/all_options")
    assert_equal %w[pagination results], reply.keys.sort
    assert_equal({"more" => true}, reply["pagination"])
    assert_equal({"id" => 120, "text" => "Product 120 (SKU-381)"}, reply["results"].first)
  end

  def test_defaults_are_fifty_a_page_newest_first
    reply = get("/admin/products/all_options")
    assert_equal (71..120).to_a.reverse, reply["results"].map { |result| result["id"] }
    last = get("/admin/products/all_options", page: 3)
    assert_equal (1..20).to_a.reverse, last["results"].map { |result| result["id"] }
    refute last["pagination"]["more"]
  end

  def test_default_search_is_the_model_search_method
    reply = get("/admin/products/all_options", term: "SKU-49")
    assert_equal 10, reply["results"].size
    assert_equal ["Product 011 (SKU-490)"], get("/admin/products/all_options", term: " SKU-490 ")["results"].map { |result| result["text"] }
  end

  def test_default_search_without_a_search_method_is_the_label_column
    assert_equal ["Customer 17"], get("/admin/customers/all_options", term: "omer 17")["results"].map { |result| result["text"] }
  end

  def test_per_page_param_overrides_the_page_size_up_to_the_limit
    assert_equal 7, get("/admin/products/all_options", per_page: 7)["results"].size
    assert_equal 50, get("/admin/products/all_options", per_page: 0)["results"].size
    assert_equal 120, get("/admin/products/all_options", per_page: 100_000)["results"].size
    assert_equal ActiveAdminTheme::SearchableSelect::MAX_PER_PAGE, ActiveAdminTheme::SearchableSelect.send(:per_page, {per_page: 50}, {per_page: "100000"})
  end

  def test_value_label_search_order_and_payload_options
    reply = get("/admin/products/sku_options", term: "SKU-49")
    assert_equal({"id" => "SKU-490", "text" => "SKU-490 Product 011", "category" => "tools"}, reply["results"].first)
    assert_equal 10, reply["results"].size
    assert_equal 20, get("/admin/products/sku_options")["results"].size
  end

  def test_scope_takes_the_params_and_name_is_a_keyword
    reply = get("/admin/products/by_category_options", category: "toys", term: "Product 00")
    assert_equal ["Product 008", "Product 006", "Product 004", "Product 002"], reply["results"].map { |result| result["text"] }
  end

  def test_allow_empty_search_false_answers_a_blank_term_with_nothing
    assert_equal({"results" => [], "pagination" => {"more" => false}}, get("/admin/products/by_category_options", category: "toys", term: "  "))
    assert_equal 50, get("/admin/products/all_options", term: "   ")["results"].size
  end

  def test_names_of_other_gems_are_accepted
    assert_equal [{"id" => 2, "text" => "PRODUCT 002"}], get("/admin/products/legacy_options", term: "SKU-499")["results"]
    assert_empty get("/admin/products/legacy_options", term: "SKU-500")["results"]
  end

  def test_ransack_params_filter_the_scope
    country = Country.find_by!(name: "Country 05")
    reply = get("/admin/cities/all_options", q: {country_id_eq: country.id})
    assert_equal ["Country 05 City 1", "Country 05 City 2", "Country 05 City 3"], reply["results"].map { |result| result["text"] }
  end

  def test_unknown_options_raise
    error = assert_raises(ArgumentError) { ActiveAdminTheme::SearchableSelect.source(:all, item_title: :name) }
    assert_match(/unknown option :item_title/, error.message)
  end
end
