# The theme's entries of the active_admin_page_objects selector map.
ActiveAdminPageObjects.register_selectors(
  # The top menu on desktop and the drawer on mobile. A browser shows one of
  # them; rack_test sees both, so the layout section takes the first.
  main_menu: "nav[data-aat-main-menu], #main-menu",
  main_menu_button: "[data-drawer-show='main-menu']",

  current_user: "[data-test-current-user]",
  logout_link: "a.aat-logout",
  server_clock: "[data-server-clock]",

  sidebar: "[data-aat-sidebar]",
  sidebar_section: "[data-aat-sidebar] .panel",
  sidebar_toggle: "[data-aat-sidebar-toggle]",
  sidebar_collapsed: "[data-aat-page][data-aat-sidebar-collapsed]",

  # The theme's own flash and kaminari partials.
  flashes: ".aat-flashes",
  flash: ".aat-flash",
  flash_notice: ".aat-flash[data-flash='notice']",
  flash_alert: ".aat-flash[data-flash='alert']",
  flash_warning: ".aat-flash[data-flash='warning']",
  flash_error: ".aat-flash[data-flash='error']",
  pagination_current: "a[aria-current='page']",
  pagination_next: "a.aat-page-next",
  pagination_previous: "a.aat-page-prev",

  # ActiveAdmin 4 removed tabs; the theme renders its own.
  tabs: ".aat-tabs",
  tabs_nav: ".aat-tabs-nav",
  tab: ".aat-tab",

  searchable_select: ".ts-wrapper",
  searchable_select_control: ".ts-control",
  searchable_select_dropdown: ".ts-dropdown",
  searchable_select_option: ".ts-dropdown-content .option[data-value]:not(.loading-more-results)",
  searchable_select_item: ".ts-control .item",
  searchable_select_item_remove: ".remove",
  searchable_select_loading: ".ts-wrapper.loading, .ts-wrapper.searching",
  searchable_select_dropdown_content: ".ts-dropdown-content",
  searchable_select_create: ".ts-dropdown .create",
  searchable_select_no_results: ".ts-dropdown .no-results",
  searchable_select_message: ".ts-dropdown .no-results, .ts-dropdown .not-loading, .ts-dropdown .loading, .ts-dropdown .no-more-results",
  # A single select searches in its dropdown, a multiple one in its control.
  searchable_select_search: ".ts-dropdown .dropdown-input, .ts-control > input",
  searchable_select_placeholder: ".ts-control > input",

  confirm_dialog: ".aat-confirm",
  confirm_dialog_trigger: ".aat-confirm-trigger",
  confirm_dialog_modal: ".aat-confirm-modal",
  confirm_dialog_title: ".aat-confirm-title",
  confirm_dialog_message: ".aat-confirm-message",
  confirm_dialog_field: ".aat-confirm-field",
  confirm_dialog_param: "input[data-aat-confirm-param]",
  confirm_dialog_cancel: ".aat-confirm-cancel",
  confirm_dialog_submit: ".aat-confirm-submit",

  secret_reveal: "[data-aat-secret-reveal]",
  secret_reveal_toggle: ".aat-secret-reveal-toggle",
  secret_reveal_error: ".aat-secret-reveal-error",

  truncate_text: ".aat-truncate",
  truncate_text_popup: ".aat-truncate-popup",
  tooltip: "[data-aat-tooltip]",
  pre_wrap: "pre.aat-pre-wrap",
  columns: ".aat-columns",
  lazy_load: "[data-aat-lazy-load]",
  panel_toggle: "[data-aat-panel-toggle]",
  notice: ".aat-notice",
  link_list: ".aat-link-lists",
  link_list_list: ".aat-link-list",
  link_list_group: ".aat-link-group",
  link_list_link: "li > a",
  link_list_label: ".aat-link-label",
  link_list_count: ".aat-link-count",
  action_item_dropdown: ".aat-dropdown",
  dropdown_menu: ".aat-dropdown",
  dropdown_menu_toggle: ".aat-dropdown-toggle",
  dropdown_menu_menu: ".aat-dropdown-menu",
  dropdown_menu_item: ".aat-dropdown-menu a"
)
