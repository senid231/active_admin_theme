# The string helpers and the notice component, with no browser: in a view, and in
# a plain object that includes ActiveAdminTheme::Helpers::Tags.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"
require "nokogiri"

class HelpersTest < Minitest::Test
  class PlainDecorator
    include ActiveAdminTheme::Helpers::Tags
  end

  def decorator
    @decorator ||= PlainDecorator.new
  end

  def view
    @view ||= ActionView::Base.empty
  end

  def element(html, selector)
    Nokogiri::HTML.fragment(html).at_css(selector)
  end

  def test_aat_arbre_returns_trimmed_html_safe_html
    html = decorator.aat_arbre { span "A & B" }
    assert_equal "<span>A &amp; B</span>", html
    assert_predicate html, :html_safe?
  end

  def test_the_helpers_are_in_views_and_in_decorators
    %i[aat_arbre status_tag_tag secret_reveal_tag notice_tag pre_wrap confirm_dialog_tag dropdown_menu_tag].each do |name|
      assert_respond_to view, name
      assert_respond_to decorator, name
    end
  end

  def test_status_tag_tag_takes_the_arguments_of_status_tag
    html = decorator.status_tag_tag("Shipped", label: "On its way", class: "big")
    tag = element(html, "span.status-tag")
    assert_equal "On its way", tag.text
    assert_equal "shipped", tag["data-status"]
    assert_includes tag["class"].split, "big"
    assert_predicate html, :html_safe?
    assert_equal "--aat-status-color:#b91c1c", element(view.status_tag_tag("Late", color: "#b91c1c"), "span")["style"]
    assert_raises(ArgumentError) { decorator.status_tag_tag("Late", color: "red;x") }
  end

  def test_danger_status_is_colored_by_the_theme_without_a_style
    tag = element(decorator.status_tag_tag("danger"), "span")
    assert_equal "danger", tag["data-status"]
    assert_nil tag["style"]
  end

  def test_secret_reveal_tag_inline_url_and_blank
    inline = element(decorator.secret_reveal_tag(value: "<b>s3</b>", mask: "***"), "[data-aat-secret-reveal]")
    assert_equal "***", inline["data-mask"]
    assert_nil inline["data-url"]
    assert_equal "&lt;b&gt;s3&lt;/b&gt;", inline.at_css("template").inner_html

    remote = element(decorator.secret_reveal_tag(url: "/secret", method: :post), "[data-aat-secret-reveal]")
    assert_equal "/secret", remote["data-url"]
    assert_equal "POST", remote["data-method"]
    assert_equal "••••••••", remote["data-mask"]

    blank = element(decorator.secret_reveal_tag, "span")
    assert_includes blank["class"], "attributes-table-empty-value"
    assert_nil blank["data-aat-secret-reveal"]

    assert_raises(ArgumentError) { decorator.secret_reveal_tag(value: "x", url: "/secret") }
  end

  def test_notice_tag_kinds_and_roles
    {info: "status", success: "status", warning: "alert", danger: "alert"}.each do |kind, role|
      box = element(decorator.notice_tag("Text <1>", kind: kind), "div.aat-notice")
      assert_equal kind.to_s, box["data-kind"]
      assert_equal role, box["role"]
      assert_equal "Text <1>", box.text
    end
    assert_equal "info", element(view.notice_tag("Plain"), "div.aat-notice")["data-kind"]
    assert_predicate decorator.notice_tag("Plain"), :html_safe?
  end

  def test_notice_tag_builds_a_body_and_rejects_an_unknown_kind
    box = element(decorator.notice_tag(kind: :danger) { para "Payment failed", class: "body" }, "div.aat-notice")
    assert_equal "Payment failed", box.at_css("p.body").text
    assert_raises(ArgumentError) { decorator.notice_tag("x", kind: :loud) }
  end

  def test_notice_component_in_an_arbre_context
    html = Arbre::Context.new { notice "Heads up", kind: :warning }.to_s
    box = element(html, "div.aat-notice")
    assert_equal "warning", box["data-kind"]
    assert_equal "Heads up", box.text
  end

  def test_pre_wrap_renders_nothing_for_blank_text
    [nil, "", "  \n"].each { |text| assert_nil decorator.pre_wrap(text), text.inspect }
    assert_nil view.pre_wrap(nil)
    refute_nil decorator.pre_wrap("0")
  end

  def test_pre_wrap_escapes_the_text
    pre = element(decorator.pre_wrap("a\n<b>"), "pre.aat-pre-wrap")
    assert_equal "a\n<b>", pre.text
    assert_nil pre["style"]
  end

  def test_pre_wrap_max_height_takes_a_css_length_or_px
    assert_equal "--aat-pre-wrap-max-height:12rem", element(decorator.pre_wrap("x", max_height: "12rem"), "pre")["style"]
    assert_equal "--aat-pre-wrap-max-height:90px", element(decorator.pre_wrap("x", max_height: 90), "pre")["style"]
    capped = element(decorator.pre_wrap("x", max_height: "40vh"), "pre")
    assert_includes capped["class"].split, "aat-pre-wrap-capped"
    assert_equal "0", capped["tabindex"]
    ["red", "10", "1rem;color:red", "calc(1px)", -5].each do |value|
      assert_raises(ArgumentError, value.inspect) { decorator.pre_wrap("x", max_height: value) }
    end
  end
end
