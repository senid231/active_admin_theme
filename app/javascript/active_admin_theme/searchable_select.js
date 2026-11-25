// Upgrades selects to Tom Select: every filter and form select (unless the
// `all` setting is off), select[data-tom-select], and the AJAX selects of the
// `searchable_select` inputs (select[data-searchable-select-url]).
// data-tom-select="false" leaves a select native. The README has the details.
import TomSelect from "tom-select"

const config = {
  all: true,
  minChars: 3,
  texts: {
    any: "Any",
    noResults: "No results matched",
    typeToSearch: "Type %{count} chars to search...",
    loading: "Loading...",
    loadingMore: "Loading more...",
    noMoreResults: "No more results",
    selectParentFirst: "Select the parent first",
    add: "Add"
  }
}

// Settings and texts apply to selects upgraded after the call.
export const configure = (overrides = {}) => {
  const { texts, ...rest } = overrides
  Object.assign(config, rest)
  Object.assign(config.texts, texts)
}

const readPageConfig = () => {
  const element = document.getElementById("active-admin-theme-config")
  try {
    if (element) configure(JSON.parse(element.textContent).searchableSelect)
  } catch (error) {
    console.warn("searchable_select: invalid #active-admin-theme-config", error)
  }
  if (window.ActiveAdminTheme && window.ActiveAdminTheme.searchableSelect) configure(window.ActiveAdminTheme.searchableSelect)
}

const REMOTE = "select[data-searchable-select-url]"
const EXPLICIT = "select[data-tom-select]"
const PREDICATE = "select[data-search-methods]"
const BOOLEAN_FILTER = ".filters-form-field.boolean select"
const FILTER = ".filters-form-field.select select"
// Descendant combinator: a field with an error has div.field_with_errors
// between the li and the select.
const FORM = "form.formtastic li.input.select select"
const AUTO = [PREDICATE, BOOLEAN_FILTER, FILTER, FORM].join(", ")

const listening = new WeakSet()

const escapeHtml = (text) => String(text).replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`)
const message = (name, text) => `<div class="${name}">${escapeHtml(text)}</div>`

const hasBlank = (el) => Array.from(el.options).some((option) => option.value === "")

const ownSettings = (el) => {
  const raw = el.dataset.tomSelect
  if (!raw || raw === "true") return null
  try {
    const parsed = JSON.parse(raw)
    return parsed && typeof parsed === "object" ? parsed : null
  } catch (error) {
    console.warn("searchable_select: invalid JSON in data-tom-select", el, error)
    return null
  }
}

const merge = (settings, overrides) => {
  if (!overrides) return settings
  const { addPlugins, removePlugins, ...rest } = overrides
  let plugins = rest.plugins || settings.plugins || []
  if (Array.isArray(addPlugins)) plugins = [...new Set([...plugins, ...addPlugins])]
  if (Array.isArray(removePlugins)) plugins = plugins.filter((plugin) => !removePlugins.includes(plugin))
  return { ...settings, ...rest, plugins, render: { ...settings.render, ...rest.render } }
}

const baseSettings = (el) => {
  const inFilter = Boolean(el.closest(".filters-form-field"))
  const search = !el.matches(`${PREDICATE}, ${BOOLEAN_FILTER}`)
  const plugins = []
  if (search && !el.multiple) plugins.push("dropdown_input")
  if (el.multiple || (hasBlank(el) && !el.matches(PREDICATE))) plugins.push("remove_button")
  const settings = {
    plugins,
    maxOptions: null,
    selectOnTab: true,
    allowEmptyOption: false,
    render: {
      no_results: () => message("no-results", config.texts.noResults),
      option_create: (data, escape) => `<div class="create">${escapeHtml(config.texts.add)} <strong>${escape(data.input)}</strong>&hellip;</div>`
    }
  }
  if (!search) settings.controlInput = null
  const blank = Array.from(el.options).find((option) => option.value === "")
  if (!el.dataset.placeholder && !(blank && blank.textContent.trim()) && inFilter) settings.placeholder = config.texts.any
  return settings
}

const parentOf = (el) => {
  const name = el.dataset.searchableSelectParentName
  if (!name) return null
  const fields = el.form ? Array.from(el.form.elements) : Array.from(document.querySelectorAll("select, input"))
  const parent = fields.find((field) => field.name === name)
  if (!parent) console.warn(`searchable_select: parent input ${name} not found`, el)
  return parent || null
}

const pageUrl = (el, parent, query, page) => {
  const url = new URL(el.dataset.searchableSelectUrl, window.location.href)
  if (query.trim()) url.searchParams.set("term", query.trim())
  url.searchParams.set("page", String(page))
  if (el.dataset.searchableSelectPerPage) url.searchParams.set("per_page", el.dataset.searchableSelectPerPage)
  if (parent && parent.value) url.searchParams.set(el.dataset.searchableSelectParentParam, parent.value)
  return url.toString()
}

const nextUrl = (href) => {
  const url = new URL(href)
  url.searchParams.set("page", String(Number(url.searchParams.get("page")) + 1))
  return url.toString()
}

const fetchPage = (href) =>
  fetch(href, { headers: { Accept: "application/json" }, credentials: "same-origin" })
    .then((response) => (response.ok ? response.json() : Promise.reject(response)))

const hasMore = (data) => Boolean(data.pagination && data.pagination.more)

const remoteFields = { valueField: "id", labelField: "text", searchField: ["text"] }

// Every page of the endpoint up front; typing filters the loaded options.
const loadAllSettings = (el, parent) => {
  const fetchAll = (page, loaded) =>
    fetchPage(pageUrl(el, parent, "", page)).then((data) => {
      const results = loaded.concat(data.results || [])
      return hasMore(data) ? fetchAll(page + 1, results) : results
    })
  return {
    ...remoteFields,
    preload: !(parent && !parent.value),
    shouldLoad: (query) => query === "",
    load(query, callback) {
      fetchAll(1, []).then((results) => { if (el.tomselect === this) callback(results) }).catch(() => callback())
    },
    render: { loading: () => message("loading", config.texts.loading) }
  }
}

const minCharsOf = (el) => {
  const own = el.dataset.searchableSelectMinChars
  return own === undefined || own === "" ? Number(config.minChars) : Number(own)
}

// One page per request; the dropdown shows the results of one query at a time.
const lazySettings = (el, parent) => {
  const minChars = minCharsOf(el)
  const state = { shown: null, pending: null, token: 0, ids: new Set() }
  el.searchableSelectState = state
  return {
    ...remoteFields,
    addPlugins: ["virtual_scroll"],
    preload: false,
    loadThrottle: 250,
    // The raw input length counts, so three spaces ask for the unfiltered list.
    shouldLoad: (query) => query.length >= minChars,
    // The server filters; a client-side text score would drop matches on other fields.
    score: (query) => (option) => (query.length >= minChars && state.ids.has(String(option.id)) ? 1 : 0),
    firstUrl: (query) => pageUrl(el, parent, query, 1),
    load(query, callback) {
      const href = this.getUrl(query)
      const first = new URL(href).searchParams.get("page") === "1"
      if (first) {
        state.token += 1
        state.pending = query
      }
      const token = state.token
      const settle = () => {
        this.loading = Math.max(this.loading - 1, 0)
        if (!this.loading) this.wrapper.classList.remove(this.settings.loadingClass)
      }
      fetchPage(href)
        .then((data) => {
          // rebuild() destroyed this instance, or a newer query was typed.
          if (el.tomselect !== this) return
          if (token !== state.token) return settle()
          if (hasMore(data)) this.setNextUrl(query, nextUrl(href))
          if (first) {
            state.ids = new Set()
            state.shown = query
            state.pending = null
          }
          const results = data.results || []
          results.forEach((result) => state.ids.add(String(result.id)))
          // A late response must not reopen a dropdown the user already closed.
          const wasOpen = this.isOpen
          callback(results)
          if (!wasOpen && this.isOpen) this.close()
        })
        .catch(() => {
          if (el.tomselect !== this) return
          if (token !== state.token) return settle()
          state.pending = null
          callback()
        })
    },
    render: {
      not_loading: () => (minChars > 0 ? message("not-loading", config.texts.typeToSearch.replace("%{count}", minChars)) : null),
      loading: () => message("loading", config.texts.loading),
      loading_more: () => message("loading-more-results", config.texts.loadingMore),
      no_more_results: () => message("no-more-results", config.texts.noMoreResults)
    }
  }
}

// Tom Select trims the input and remembers the queries it served. A lazy
// select needs the raw input (three spaces) and a fresh first page whenever
// the query is not the one on screen, such as after a backspace.
const patchLazy = (el, select) => {
  const state = el.searchableSelectState
  const minChars = minCharsOf(el)
  select.inputValue = () => select.control_input.value
  const canLoad = select.canLoad.bind(select)
  select.canLoad = (query) => {
    if (query !== state.shown && query !== state.pending) {
      select.clearPagination()
      delete select.loadedSearches[query]
    }
    return canLoad(query)
  }
  select.on("type", (query) => { if (query.length < minChars) state.shown = null })
  if (minChars === 0) select.on("focus", () => { if (state.shown === null) select.load("") })
}

const settingsFor = (el, parent) => {
  let settings = baseSettings(el)
  const remote = el.matches(REMOTE)
  const lazy = remote && !("searchableSelectLoadAll" in el.dataset)
  if (remote) settings = merge(settings, lazy ? lazySettings(el, parent) : loadAllSettings(el, parent))
  settings = merge(settings, ownSettings(el))
  if (parent && !parent.value) settings.placeholder = el.dataset.searchableSelectParentPlaceholder || config.texts.selectParentFirst
  return { settings, lazy }
}

// Picking an option in a single select hands focus back to the control, and
// Tom Select then reopens the dropdown on its own. Ignore opens that follow a
// pick until the user presses the control again.
const closeAfterPick = (select) => {
  let picked = false
  const open = select.open.bind(select)
  select.open = () => { if (!picked) open() }
  select.on("item_add", () => { picked = true })
  select.control.addEventListener("mousedown", () => { picked = false }, true)
  select.wrapper.addEventListener("keydown", () => { picked = false }, true)
}

const build = (el, parent) => {
  if (parent) el.dataset.searchableSelectParentValue = parent.value
  const { settings, lazy } = settingsFor(el, parent)
  const select = new TomSelect(el, settings)
  if (lazy) patchLazy(el, select)
  // Without a search input nothing shows the placeholder; the CSS prints this.
  if (!select.control_input.isConnected && select.settings.placeholder) select.control.dataset.placeholder = select.settings.placeholder
  if (!el.multiple) closeAfterPick(select)
  if (parent && !parent.value) select.disable()
}

const rebuild = (el, parent) => {
  if (el.tomselect) el.tomselect.destroy()
  Array.from(el.options).forEach((option) => { if (option.value !== "") option.remove() })
  el.disabled = false
  // Lets selects that depend on this one reset too.
  el.dispatchEvent(new Event("change", { bubbles: true }))
  build(el, parent)
}

const wanted = (el) => {
  if (el.tomselect || el.classList.contains("ts-hidden-accessible") || el.closest("template")) return false
  if (el.dataset.tomSelect === "false") return false
  return el.matches(`${REMOTE}, ${EXPLICIT}`) || (config.all && el.matches(AUTO))
}

export const upgrade = (el) => {
  if (!wanted(el)) return
  const parent = parentOf(el)
  build(el, parent)
  if (parent && !listening.has(el)) {
    listening.add(el)
    parent.addEventListener("change", () => {
      if (el.dataset.searchableSelectParentValue !== parent.value) rebuild(el, parent)
    })
  }
}

export const upgradeAll = (root = document) => {
  if (root.matches && root.matches("select")) upgrade(root)
  if (root.querySelectorAll) root.querySelectorAll("select").forEach(upgrade)
}

const start = () => {
  readPageConfig()
  upgradeAll(document)
  // Selects added later, such as has_many rows and dialogs.
  new MutationObserver((records) => {
    records.forEach((record) => {
      record.addedNodes.forEach((node) => { if (node.nodeType === 1) upgradeAll(node) })
    })
  }).observe(document.body, { childList: true, subtree: true })
}

if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start)
else start()
document.addEventListener("turbo:load", () => upgradeAll(document))
