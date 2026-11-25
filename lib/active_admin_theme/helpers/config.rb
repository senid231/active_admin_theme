module ActiveAdminTheme
  module Helpers
    module Config
      SEARCHABLE_SELECT_TEXTS = {
        any: "Any",
        no_results: "No results matched",
        type_to_search: "Type %{count} chars to search...",
        loading: "Loading...",
        loading_more: "Loading more...",
        no_more_results: "No more results",
        select_parent_first: "Select the parent first",
        add: "Add"
      }.freeze

      # The settings the theme's scripts read, as a JSON element. Texts come
      # from `active_admin_theme.searchable_select.*` with English defaults.
      def active_admin_theme_config_tag
        texts = SEARCHABLE_SELECT_TEXTS.to_h do |key, default|
          [key.to_s.camelize(:lower), I18n.t("active_admin_theme.searchable_select.#{key}", default: default)]
        end
        config = {searchableSelect: {all: ActiveAdminTheme.searchable_select_all, minChars: ActiveAdminTheme.searchable_select_min_chars, texts: texts}}
        content_tag(:script, json_escape(config.to_json).html_safe, type: "application/json", id: "active-admin-theme-config")
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::Config }
