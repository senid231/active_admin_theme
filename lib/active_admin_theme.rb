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
  DEFAULT_JAVASCRIPTS = %w[
    active_admin_theme/layout
    active_admin_theme/server_clock
    active_admin_theme/table_crisscross
    active_admin_theme/searchable_select
  ].freeze

  class << self
    attr_writer :javascripts, :searchable_select_all, :searchable_select_min_chars

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
  end
end
