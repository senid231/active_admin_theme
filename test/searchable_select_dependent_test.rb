# Browser test (headless Chrome): the dependent-select options of the
# searchable select, on the dependent lab page.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"

class SearchableSelectDependentTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  OPTION = ".ts-dropdown-content .option[data-value]:not(.loading-more-results)".freeze

  def setup
    page.current_window.resize_to(1280, 900)
  end

  def teardown
    Capybara.reset_sessions!
  end

  def test_several_parents_a_checkbox_and_an_optional_parent
    visit "/admin/dependent_lab"
    spy_on_fetch
    # The street is optional, so only the city waits for its parents.
    assert_selector "#lab-several .ts-wrapper.disabled", count: 1
    assert_selector "#lab-several .ts-wrapper.disabled input[placeholder='Pick countries first']", visible: :all
    street = wrapper_for("shipment[street_id]")
    open_dropdown(street)
    street.assert_selector OPTION, count: Street.count

    pick_many("shipment[country_id][]", "Country 05")
    pick_many("shipment[country_id][]", "Country 06")
    assert_no_selector "#lab-several .ts-wrapper.disabled"
    city = wrapper_for("shipment[city_id]")
    open_dropdown(city)
    city.assert_selector OPTION, count: 6
    # Six options are not one, so nothing is selected for the user.
    city.assert_no_selector ".item"
    params = fetched("/admin/cities/all_options").last
    assert_equal Country.where(name: ["Country 05", "Country 06"]).ids.map(&:to_s).sort, params["q[country_id_in][]"].sort
    assert_equal ["false"], params["insured"]

    find("input[type=checkbox][name='shipment[insured]']").click
    city = wrapper_for("shipment[city_id]")
    open_dropdown(city)
    city.assert_selector OPTION, count: 6
    assert_equal ["true"], fetched("/admin/cities/all_options").last["insured"]

    pick_plain("shipment[city_id]", "Country 05 City 1")
    street = wrapper_for("shipment[street_id]")
    open_dropdown(street)
    street.assert_selector OPTION, count: 2
    assert_equal [City.find_by!(name: "Country 05 City 1").id.to_s], fetched("/admin/streets/all_options").last["q[city_id_eq]"]
  end

  def test_auto_select_picks_the_only_option_of_a_fill
    visit "/admin/dependent_lab"
    pick("order[country_id]", "Country 05")
    city = City.where(country: Country.find_by!(name: "Country 05")).minimum(:id)
    wrapper_for("order[city_id]").assert_selector ".item", text: "Country 05 City 1"
    assert_equal city.to_s, find("select[name='order[city_id]']", visible: :all).value
  end

  def test_a_bare_array_reply_with_value_as_the_id
    visit "/admin/dependent_lab"
    customer = wrapper_for("order[customer_id]")
    open_dropdown(customer)
    customer.assert_selector OPTION, count: 5
    pick("order[customer_id]", "Customer 17")
    assert_equal Customer.find_by!(name: "Customer 17").id.to_s, find("select[name='order[customer_id]']", visible: :all).value
  end

  private

  def wrapper_for(name)
    find(:xpath, "//select[@name='#{name}']/following-sibling::div[contains(@class, 'ts-wrapper')][1]", visible: :all)
  end

  def search(wrapper, text)
    wrapper.find(".dropdown-input").send_keys(text)
  end

  def open_dropdown(wrapper)
    wrapper.find(".ts-control").click unless wrapper.has_css?(".ts-dropdown", visible: :visible, wait: false)
    wrapper.assert_selector ".ts-dropdown", visible: :visible
  end

  def pick(name, text)
    wrapper = wrapper_for(name)
    open_dropdown(wrapper)
    search(wrapper, text)
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    wrapper.assert_selector OPTION, count: 1, text: text
    wrapper.find(OPTION, text: text).click
    wrapper_for(name).assert_selector ".item", text: text
  end

  # A multiple select has no search box of its own: the typed text sits in the
  # control, and stays there after a pick.
  def pick_many(name, text)
    wrapper = wrapper_for(name)
    wrapper.find(".ts-control").click
    # Backspace in an empty Tom Select input removes the last item, so clear the search text directly.
    input = wrapper.find(".ts-control > input")
    input.execute_script("this.value = ''")
    input.send_keys(text)
    assert_no_selector ".ts-wrapper.loading, .ts-wrapper.searching"
    wrapper.assert_selector OPTION, count: 1, text: text
    wrapper.find(OPTION, text: text).click
    wrapper_for(name).assert_selector ".item", text: text
  end

  def pick_plain(name, text)
    wrapper = wrapper_for(name)
    open_dropdown(wrapper)
    wrapper.find(OPTION, exact_text: text).click
    wrapper_for(name).assert_selector ".item", text: text
  end

  # The requests the page makes from now on, to read their params.
  def spy_on_fetch
    page.execute_script("window.fetched = []; const original = window.fetch; window.fetch = (url, options) => { window.fetched.push(String(url)); return original(url, options) }")
  end

  def fetched(path)
    page.evaluate_script("window.fetched").map { |url| URI(url) }.select { |uri| uri.path == path }.map { |uri| CGI.parse(uri.query.to_s) }
  end
end
