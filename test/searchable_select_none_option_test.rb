# The options endpoint with active_admin_filter_extensions' None marker, which a
# dependent select passes on from its parent. No browser. The filter gem is
# loaded here only, so the other tests run without it.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/application"
require "active_admin_filter_extensions"
require_relative "dummy/config/environment"
require "minitest/autorun"

class SearchableSelectNoneOptionTest < Minitest::Test
  def setup
    @nowhere = City.new(name: "Nowhere")
    @nowhere.save!(validate: false)
  end

  def teardown
    @nowhere.delete
  end

  def labels(query)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.get "/admin/cities/all_options?#{query}"
    assert_equal 200, session.response.status
    JSON.parse(session.response.body).fetch("results").map { |result| result["text"] }
  end

  def test_the_marker_finds_records_without_the_parent
    marker = ActiveAdminFilterExtensions.none_value
    assert_equal ["Nowhere"], labels("q[country_id_eq]=#{marker}")
  end

  def test_the_marker_beside_values_finds_both
    marker = ActiveAdminFilterExtensions.none_value
    country = Country.order(:id).first
    found = labels("q[country_id_in][]=#{marker}&q[country_id_in][]=#{country.id}&per_page=100")
    assert_includes found, "Nowhere"
    assert_equal City.where(country: country).pluck(:name).sort, (found - ["Nowhere"]).sort
  end

  def test_a_filter_drops_the_marker_from_its_selected_options
    marker = ActiveAdminFilterExtensions.none_value
    country = Country.order(:id).first
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.get "/admin/grouped_cities?q[country_id_in][]=#{marker}&q[country_id_in][]=#{country.id}"
    assert_equal 200, session.response.status
    options = Nokogiri::HTML(session.response.body).css("select[name='q[country_id_in][]'] option").map { |option| option["value"] }
    assert_equal [country.id.to_s], options.compact_blank
  end
end
