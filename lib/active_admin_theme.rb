# ActiveAdmin first: Rails prepends each engine's view path in the order the
# engine classes are defined, so the theme's partials win over ActiveAdmin's
# only when ActiveAdmin::Engine is defined before ActiveAdminTheme::Engine.
require "active_admin"
require "active_admin_theme/version"

module ActiveAdminTheme
  # True when ActiveAdmin has the layout partials the theme overrides
  # (activeadmin/activeadmin#9149 and #9150).
  def self.layout_hooks?
    ActiveAdmin::Engine.root.join("app/views/active_admin/_page_heading.html.erb").exist?
  end
end

require "active_admin_theme/engine"

module ActiveAdminTheme
  # ES modules the layout imports after ActiveAdmin's own entry point. Edit the
  # list in an initializer to load fewer scripts or to add the opt-in ones:
  #   ActiveAdminTheme.javascripts -= %w[active_admin_theme/table_crisscross]
  #   ActiveAdminTheme.javascripts += %w[active_admin_theme/secret_reveal]
  DEFAULT_JAVASCRIPTS = %w[
    active_admin_theme/layout
    active_admin_theme/server_clock
    active_admin_theme/tabs
    active_admin_theme/dropdown_menu
    active_admin_theme/table_crisscross
    active_admin_theme/searchable_select
    active_admin_theme/confirm_dialog
    active_admin_theme/panel_toggle
  ].freeze

  class << self
    # Page size of a searchable_select_options endpoint that declares no per_page:. Nil means 50.
    attr_accessor :searchable_select_per_page

    attr_writer :javascripts, :searchable_select_all, :searchable_select_min_chars
    # nil keeps ActiveAdmin's "Powered by" footer; any of the three replaces it.
    # footer_extra and site_title_link are a String, or a Proc run in the view.
    # site_title_link false or nil leaves the title as plain text.
    attr_accessor :footer_product_name, :footer_version, :footer_extra, :site_title_link

    def javascripts
      @javascripts ||= DEFAULT_JAVASCRIPTS.dup
    end

    # True when active_admin_theme/searchable_select upgrades every filter and
    # form select. False leaves it to `as: :searchable_select` and `tom_select:`.
    def searchable_select_all
      @searchable_select_all.nil? ? true : @searchable_select_all
    end

    # Characters to type before a searchable select asks its endpoint.
    def searchable_select_min_chars
      @searchable_select_min_chars || 3
    end

    # Globs of the theme's files that hold Tailwind class names.
    def tailwind_content
      root = Engine.root
      [root.join("app/**/*.{arb,erb,html,rb,js}").to_s, root.join("lib/**/*.rb").to_s]
    end

    # `@source` lines for a host's Tailwind CSS. With relative_to (a directory),
    # paths are relative to it, so the lines hold no machine-specific path.
    def tailwind_sources(relative_to: nil)
      tailwind_content.map do |glob|
        glob = Pathname.new(glob).relative_path_from(Pathname.new(relative_to).expand_path).to_s if relative_to
        %(@source "#{glob}";)
      end
    end
  end
end
